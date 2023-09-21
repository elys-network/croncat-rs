&nbsp;

<div align="center">
<img width="300px" src="./croncat.png" />
</div>

&nbsp;

---

# croncat-rs

`croncat-rs` is the brand new version of the croncat agent, written in Rust.

## Modules

-   `croncatd` The executable agent daemon.
-   `croncat` All the pieces to build an agent daemon.

## Development Tools

-   `cargo install rusty-hook cargo-make`
-   `rusty-hook init`

## Help

```
$ cargo run help
...
croncatd 0.3.0
The croncat agent daemon.

USAGE:
    croncatd [FLAGS] [OPTIONS] <SUBCOMMAND>

FLAGS:
    -d, --debug        Debug mode
    -h, --help         Prints help information
        --no-frills    Whether to print nice little things like the banner and a goodbye
    -V, --version      Prints version information

OPTIONS:
        --agent <agent>          ID of the agent config to use [env: CRONCAT_AGENT=]  [default: agent]
        --chain-id <chain-id>    Chain ID of the chain to connect to [env: CRONCAT_CHAIN_ID=uni-6]

SUBCOMMANDS:
    all-tasks            Get contract's state Show all task(s) information
    generate-mnemonic    Generates a new keypair and agent account (good first step)
    get-agent-keys       [SENSITIVE!] Shows all details about agents on this machine
    get-tasks            Get the agent's tasks they're assigned to fulfill
    go                   Starts the Croncat agent, allowing it to fulfill tasks
    help                 Prints this message or the help of the given subcommand(s)
    list-accounts        Get the agent's supported bech32 accounts
    register             Registers an agent, placing them in the pending queue unless it's the first agent
    send                 Send funds from the agent account to another account
    setup-service        Setup an agent as a system service (systemd)
    status               Get the agent's status (pending/active)
    unregister           Unregisters the agent from being in the queue with other agents
    update               Update the agent's configuration
    withdraw             Withdraw the agent's funds to the payable account ID

Example:
$ cargo run -- --debug status

```

## Setup

### Prerequisites

Clone the elys Repository and the cw-croncat repository in a separate directory

```bash
git clone git@github.com:elys-network/elys.git
git clone git@github.com:CronCats/cw-croncat.git

```

-move the script from `init_croncat_contract.sh` to the cw-croncat reposirory

-move the `agents.json` to `~/../.croncatd/`

-add to the elys repository `config.yml` in the accounts field the agent123:

```yml
accounts:
    - name: agent123
      coins:
          - 100000000uatom
          - 100000000uusdt
          - 9000000000000000uelys
          - 100000000ueden
      mnemonic: eternal bring move black rich spatial term odor sadness weather inform just trial budget domain awkward foam minute scrub gentle appear plastic during gaze
```

### Start the elys local net

in the elys repository:

```bash
ignite chain serve -r
```

### Register an agent and create a task

in the cw-croncat repository:

```bash
sh init_croncat_contract.sh
```

### Start the agent node

in this repository:

-define the environent variable

```bash
export CRONCAT_CHAIN_ID=agent123
export CRONCAT_AGENT=elystestnet-1
```

-check if everything is alright

```
cargo run status
```

-start the node

```
cargo run go
```

### Go for executing tasks

```bash
cargo run go
```

### Claim Rewards

After a while, time to claim some rewards if you've been actively processing tasks!

```bash
# Check if you have any rewards, see "Earned Rewards"
# NOTE: Also shows how much balance your agent has for processing txns
cargo run status

# Claim rewards
cargo run withdraw
```

## Code of Conduct

-   Please see [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)

## Contributing

-   Please see [CONTRIBUTING.md](./CONTRIBUTING.md)

### Chain Registry:

For clearing the latest local cache of chain registry, `rm -rf .cosmos-chain-registry`, then build.

### This project is made possible by these awesome contributors!

<a href="https://github.com/CronCats/croncat-rs/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=CronCats/croncat-rs" />
</a>
