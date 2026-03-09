# torch-hpc-ssr

**torch-hpc-ssr** (Submit Slurm Request) is a small interactive Bash helper that simplifies requesting CPU/GPU resources on a Slurm-based HPC cluster.

---

## Setup Guide

### 1. Adapt the account list

Before using the script, edit the GPU account options in the script to match the accounts available to you on your HPC system.

Locate the sections:

```bash
# multiple options for GPUs
account="$(prompt_menu \        # L227
  "8) Select account:" \
  1 \
  "torch_pr_56_tandon_advanced" \
  "torch_pr_676_tandon_advanced" \
  "torch_pr_676_tandon_priority")"

# fixed option for CPUs
account="torch_pr_56_general"   # L234
```

Replace the account names with the accounts assigned to your user.

---

### 2. Create a convenient command alias

Add the following line to your `~/.bashrc` so you can run the script from anywhere:

```bash
alias ssr='bash /path/to/script/ssr.sh'
```

Then reload your shell configuration:

```bash
[hl3797@torch-login-0 ~]$ source ~/.bashrc
```

Now you can launch the interactive helper with:

```bash
[hl3797@torch-login-0 ~]$ ssr
```

---

## License

This project is released under the **CC BY-NC-SA 4.0** license.

**Authors:** Hammond Liu & ChatGPT 5.4  
**Contact:** hl3797 AT nyu DOT edu