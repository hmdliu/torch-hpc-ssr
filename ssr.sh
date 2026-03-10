#!/usr/bin/env bash
# ------------------------------------------------------------------
# Interactive Slurm resource request helper
#
# License: CC BY-NC-SA 4.0
# Authors: Hammond Liu & ChatGPT 5.4
# Contact: hl3797 AT nyu DOT edu
# ------------------------------------------------------------------

set -u

# Exit cleanly on Ctrl+C.
trap 'echo; echo "Aborted by user."; exit 130' INT

print_notice() {
  cat <<'EOF'
============================================================
Slurm Interactive Request Helper
License: CC BY-NC-SA 4.0
Authors: Hammond Liu & ChatGPT 5.4
Contact: hl3797 AT nyu DOT edu
============================================================

EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

prompt_menu() {
  # Usage:
  #   prompt_menu "Prompt text" default_index "opt1" "opt2" ...
  #
  # Contract:
  #   - All UI text goes to stderr
  #   - Only the final selected value is printed to stdout
  #
  # This allows safe use with command substitution:
  #   value="$(prompt_menu ...)"
  #
  local prompt="$1"
  local default_index="$2"
  shift 2
  local options=("$@")

  local num_options="${#options[@]}"
  local reply
  local i

  while true; do
    echo "$prompt" >&2
    for ((i=0; i<num_options; i++)); do
      if [[ $((i + 1)) -eq "$default_index" ]]; then
        echo "  $((i + 1))) ${options[i]} [default]" >&2
      else
        echo "  $((i + 1))) ${options[i]}" >&2
      fi
    done

    read -r -p "Enter choice [default: ${default_index}]: " reply

    if [[ -z "$reply" ]]; then
      echo "${options[$((default_index - 1))]}"
      return 0
    fi

    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= num_options )); then
      echo "${options[$((reply - 1))]}"
      return 0
    fi

    echo "Invalid input. Please enter a number between 1 and ${num_options}, or press Enter for default." >&2
    echo >&2
  done
}

prompt_positive_int() {
  # Contract:
  #   - Only the validated integer is printed to stdout
  #   - Any retry/error text goes to stderr
  #
  local prompt="$1"
  local default_value="$2"
  local reply

  while true; do
    read -r -p "${prompt} [default: ${default_value}]: " reply

    if [[ -z "$reply" ]]; then
      echo "$default_value"
      return 0
    fi

    if [[ "$reply" =~ ^[1-9][0-9]*$ ]]; then
      echo "$reply"
      return 0
    fi

    echo "Invalid input. Please enter a positive integer, or press Enter for default." >&2
  done
}

prompt_memory() {
  # Accept common Slurm-style memory strings, e.g.:
  #   32GB, 64G, 8000M, 1TB
  #
  # Contract:
  #   - Only the validated memory string is printed to stdout
  #   - Any retry/error text goes to stderr
  #
  local prompt="$1"
  local default_value="$2"
  local reply

  while true; do
    read -r -p "${prompt} [default: ${default_value}]: " reply

    if [[ -z "$reply" ]]; then
      echo "$default_value"
      return 0
    fi

    if [[ "$reply" =~ ^[1-9][0-9]*([KkMmGgTtPp])([Bb])?$ ]]; then
      echo "$reply"
      return 0
    fi

    echo "Invalid input. Use a Slurm-style memory string like 32GB, 64G, 8000M, or press Enter for default." >&2
  done
}

prompt_confirm() {
  local reply
  while true; do
    echo "Run this command now?"
    echo "  1) yes [default]"
    echo "  2) no"
    read -r -p "Enter choice [default: 1]: " reply

    if [[ -z "$reply" || "$reply" == "1" ]]; then
      return 0
    elif [[ "$reply" == "2" ]]; then
      return 1
    else
      echo "Invalid input. Please enter 1 or 2, or press Enter for default."
    fi
  done
}

build_time_string() {
  # Convert an integer hour count to Slurm HH:MM:SS format.
  local hours="$1"
  echo "${hours}:00:00"
}

quote_arg_for_display() {
  # Pretty-print a command argument for display in a shell-safe way.
  # This is only for showing the command to the user; execution uses
  # the original array values directly.
  local arg="$1"

  # Safe unquoted shell token
  if [[ "$arg" =~ ^[A-Za-z0-9_./:=,@+-]+$ ]]; then
    printf '%s' "$arg"
  else
    # Single-quote and escape any embedded single quotes
    arg=${arg//\'/\'\\\'\'}
    printf "'%s'" "$arg"
  fi
}

print_command_pretty() {
  # Render a command array as a readable shell command line.
  local arg
  for arg in "$@"; do
    quote_arg_for_display "$arg"
    printf ' '
  done
  printf '\n'
}

main() {
  print_notice

  # Total interactive workflow steps shown to the user.
  local total_steps=8

  local submit_mode
  local job_kind
  local cpus
  local mem
  local hours
  local time_str
  local gpu_type=""
  local gpu_count=""
  local account=""

  submit_mode="$(prompt_menu \
    "[1/${total_steps}] Select submission mode:" \
    1 \
    "sbatch" \
    "srun")"

  echo

  job_kind="$(prompt_menu \
    "[2/${total_steps}] Select job type:" \
    1 \
    "gpu" \
    "cpu")"

  echo

  cpus="$(prompt_positive_int \
    "[3/${total_steps}] Number of CPUs (--cpus-per-task)" \
    4)"

  echo

  mem="$(prompt_memory \
    "[4/${total_steps}] Memory (--mem)" \
    "32GB")"

  echo

  hours="$(prompt_positive_int \
    "[5/${total_steps}] Time in hours (--time)" \
    2)"
  time_str="$(build_time_string "$hours")"

  echo

  if [[ "$job_kind" == "gpu" ]]; then
    gpu_type="$(prompt_menu \
      "[6/${total_steps}] Select GPU type:" \
      1 \
      "any" \
      "h200" \
      "h100" \
      "a100" \
      "l40s")"

    echo

    gpu_count="$(prompt_positive_int \
      "[7/${total_steps}] Number of GPUs" \
      1)"

    echo

    # TODO: Fill in your GPU accounts below
    account="$(prompt_menu \
      "[8/${total_steps}] Select account:" \
      1 \
      "torch_pr_56_tandon_advanced" \
      "torch_pr_676_tandon_advanced" \
      "torch_pr_676_tandon_priority")"
  else
    # CPU jobs skip GPU-specific questions and use the CPU default account.
    # TODO: Fill in your CPU account below
    account="torch_pr_56_general"
    echo "[6/${total_steps}] GPU type: skipped (CPU job)"
    echo "[7/${total_steps}] GPU count: skipped (CPU job)"
    echo "[8/${total_steps}] Account: ${account} [CPU default]"
  fi

  echo
  echo "==================== Summary ===================="
  echo "Submission mode : ${submit_mode}"
  echo "Job type        : ${job_kind}"
  echo "CPUs            : ${cpus}"
  echo "Memory          : ${mem}"
  echo "Time            : ${time_str}"
  if [[ "$job_kind" == "gpu" ]]; then
    echo "GPU type        : ${gpu_type}"
    echo "GPU count       : ${gpu_count}"
  fi
  echo "Account         : ${account}"
  echo "================================================"
  echo

  # Build the command as an array to avoid word-splitting bugs.
  local -a cmd
  cmd=(
    "$submit_mode"
    "--nodes=1"
    "--cpus-per-task=${cpus}"
    "--mem=${mem}"
    "--time=${time_str}"
    "--account=${account}"
  )

  if [[ "$job_kind" == "gpu" ]]; then
    if [[ "$gpu_type" == "any" ]]; then
      cmd+=("--gres=gpu:${gpu_count}")
    else
      cmd+=("--gres=gpu:${gpu_type}:${gpu_count}")
    fi
  fi

  # Interactive shell for srun; persistent placeholder job for sbatch.
  if [[ "$submit_mode" == "srun" ]]; then
    cmd+=("--pty" "/bin/bash")
  else
    cmd+=("--wrap" "sleep infinity")
  fi

  echo "Command to run:"
  print_command_pretty "${cmd[@]}"
  echo

  if prompt_confirm; then
    echo "Submitting..."
    "${cmd[@]}"
  else
    echo "Cancelled. No command was run."
  fi
}

main "$@"