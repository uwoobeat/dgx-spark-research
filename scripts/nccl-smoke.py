#!/usr/bin/env python3
import os
import socket
import time

import torch
import torch.distributed as dist


def main() -> None:
    dist.init_process_group("nccl")
    rank = dist.get_rank()
    world = dist.get_world_size()
    if world != 2:
        raise RuntimeError(f"expected world_size=2, got {world}")

    torch.cuda.set_device(0)
    value = torch.tensor([float(rank + 1)], device="cuda")
    dist.all_reduce(value, op=dist.ReduceOp.SUM)
    torch.cuda.synchronize()
    if value.item() != 3.0:
        raise RuntimeError(f"unexpected all_reduce result: {value.item()}")

    # 64 MiB payload: enough to exercise the selected network without acting as
    # a formal bandwidth benchmark.
    payload = torch.ones(16 * 1024 * 1024, dtype=torch.float32, device="cuda")
    dist.barrier()
    started = time.monotonic()
    for _ in range(4):
        dist.all_reduce(payload, op=dist.ReduceOp.SUM)
    torch.cuda.synchronize()
    elapsed = time.monotonic() - started

    print(
        f"NCCL_SMOKE_OK rank={rank} host={socket.gethostname()} "
        f"world={world} elapsed_s={elapsed:.3f}",
        flush=True,
    )
    dist.destroy_process_group()


if __name__ == "__main__":
    os.environ.setdefault("TORCH_NCCL_ASYNC_ERROR_HANDLING", "1")
    main()

