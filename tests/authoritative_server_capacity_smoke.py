#!/usr/bin/env python3
"""Short-lived WSS admission smoke test for the dedicated Godot server.

This checks transport admission up to the configured player ceiling. It does
not authenticate users or measure full gameplay, so it is not a capacity
benchmark for a production city session.
"""
import argparse
import asyncio
import json
import ssl
import statistics
import time

import websockets


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="wss://127.0.0.1:2456")
    parser.add_argument("--capacity", type=int, default=64)
    args = parser.parse_args()

    if args.capacity < 1 or args.capacity > 64:
        raise SystemExit("--capacity must be between 1 and 64")

    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    # Godot's bundled mbedTLS server currently fails the TLS 1.3 PSA
    # handshake in this Linux container (-0x6c00). Pin this smoke client
    # to TLS 1.2 so the test measures WebSocket admission, not TLS 1.3.
    tls.maximum_version = ssl.TLSVersion.TLSv1_2
    tls.check_hostname = False
    tls.verify_mode = ssl.CERT_NONE

    clients = []
    latencies_ms = []
    stage_results = []
    stages = sorted(set(n for n in (20, 30, 50, args.capacity) if n <= args.capacity))
    if not stages or stages[-1] != args.capacity:
        stages.append(args.capacity)

    async def connect_one():
        started = time.perf_counter()
        ws = await websockets.connect(
            args.url,
            ssl=tls,
            subprotocols=["binary"],
            open_timeout=5,
            close_timeout=1,
            ping_interval=None,
            max_size=None,
        )
        latencies_ms.append((time.perf_counter() - started) * 1000.0)
        return ws

    try:
        previous = 0
        for target in stages:
            count = target - previous
            new_clients = await asyncio.wait_for(
                asyncio.gather(*(connect_one() for _ in range(count))),
                timeout=7,
            )
            clients.extend(new_clients)
            await asyncio.sleep(0.25)
            still_open = sum(1 for ws in clients if not ws.closed)
            stage_results.append({
                "target": target,
                "connected": len(clients),
                "still_open": still_open,
            })
            if still_open != target:
                raise RuntimeError(
                    f"At stage {target}, expected {target} open connections, got {still_open}"
                )
            previous = target

        overflow = await connect_one()
        await asyncio.sleep(0.5)
        overflow_was_rejected = overflow.closed
        await overflow.close()
        if not overflow_was_rejected:
            raise RuntimeError(
                f"Server accepted a connection beyond configured capacity {args.capacity}"
            )

        report = {
            "result": "passed",
            "configured_capacity": args.capacity,
            "stages": stage_results,
            "overflow_connection_rejected": overflow_was_rejected,
            "connection_latency_ms": {
                "median": round(statistics.median(latencies_ms), 2),
                "p95": round(sorted(latencies_ms)[int((len(latencies_ms) - 1) * 0.95)], 2),
                "max": round(max(latencies_ms), 2),
            },
            "scope": "WSS transport admission only; no player authentication or gameplay simulation",
        }
        print(json.dumps(report, indent=2))
    finally:
        await asyncio.gather(*(ws.close() for ws in clients), return_exceptions=True)


if __name__ == "__main__":
    asyncio.run(main())
