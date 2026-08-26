# vhr-bench: VPS Host Review benchmark tool

A free, open-source command-line tool that measures the real performance of any Linux VPS.
It tests the processor, memory, and disk, and can optionally upload the result to your
[VPS Host Review](https://vpshostreview.com) account so you can attach it to a review.

**Read the source before you run it.** The tool is a single, readable Bash script:
[`vhr-bench`](./vhr-bench). It prints the exact JSON it will send and asks for your
confirmation before anything leaves your server.

## What it measures

| Area | Tool | Metric |
|---|---|---|
| Processor | `sysbench cpu` | events per second |
| Memory | `sysbench memory` | MB/s throughput |
| Disk | `fio` (random 4k) | read/write IOPS and MB/s |

It also records basic hardware context (processor model, core count, total memory,
distribution, kernel, and virtualization type) so results are comparable.

## What is NOT sent

Your hostname, IP address, file contents, and credentials are never collected or sent.
Results upload to your account and stay private until **you** choose to attach one to a
review, which is the only way it becomes part of the public provider comparison.

## Install

Review [`install.sh`](./install.sh) first, then:

```bash
curl -fsSL https://github.com/vpshostreview/vhr-vps-benchmark/releases/latest/download/install.sh | sudo bash
```

For supply-chain safety, prefer a pinned release tag over `main`, and verify the published
`sha256` checksum of `vhr-bench` after download:

```bash
sha256sum /usr/local/bin/vhr-bench
```

## Run

Get your personal upload token from <https://vpshostreview.com/user/benchmarks>, then:

```bash
vhr-bench --token YOUR_UPLOAD_TOKEN
```

Options:

| Flag | Purpose |
|---|---|
| `--token TOKEN` | Your upload token (or set `VHR_BENCHMARK_TOKEN`) |
| `--api-url URL` | Override the submit endpoint (for local testing) |
| `-y`, `--yes` | Skip the install and upload confirmations |
| `-h`, `--help` | Show help |

## Requirements

Linux with one of: `apt-get`, `dnf`, `yum`, `zypper`, or `apk`. The tool installs
`sysbench`, `fio`, and `curl` on first run if they are missing. These upstream tools remain
under their own licenses; this project only invokes them and does not redistribute them.

## License

MIT. See [LICENSE](./LICENSE).
