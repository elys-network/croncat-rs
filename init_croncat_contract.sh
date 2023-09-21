print_address() {
    var_name="$1"
    var_value="${!var_name}"
    var_name_colored="\e[1;34m$var_name\e[0m"  # This will make the variable name blue and bold
    
    echo -e "$var_name_colored:"
    echo "$var_value"
    echo ""

    echo -e "$var_name:" >> info
    echo "$var_value" >> info
    echo "" >> info
}
echo "" > info
# Function to extract the transaction hash from a command's output
extract_txhash() {
    output="$("$@")"
    txhash_line=$(echo "$output" | grep -o 'txhash: [[:xdigit:]]*')
    txhash=${txhash_line##* }
    echo "$txhash"
}

# Function to extract the contract address from a command's output
extract_contract_address() {
    output="$("$@")"
    contract_address=$(echo "$output" | awk -F 'key: _contract_address|value: ' '/key: _contract_address/ { getline; print $2; exit }')
    echo "$contract_address"
}

# Initialize latest_code_id
latest_code_id=0

# Function to store a Wasm contract
store() {
    path="$1"
    latest_code_id=$((latest_code_id + 1))
    # Deploy the contract with specific parameters
    elysd tx wasm store "$path" --from=treasury --keyring-backend=test --chain-id=elystestnet-1 --gas=auto --gas-adjustment=1.3 -y -b=sync
}

# Function to initialize a Wasm contract
init() {
    message="$1"
    label="$2"
    # Instantiate the contract and extract the transaction hash
    instantiate_hash=$(extract_txhash elysd tx wasm instantiate "$latest_code_id" "$message" --from=treasury --label $label --chain-id=elystestnet-1 --gas=auto --gas-adjustment=1.3 -b=sync --keyring-backend=test --no-admin -y 2> /dev/null)
    sleep 2
    # Get the contract address from the transaction hash
    addr=$(extract_contract_address elysd q tx "$instantiate_hash")
    echo "$addr"
}
TXFLAG="--from=treasury  --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y  --keyring-backend=test --chain-id=elystestnet-1"


# Store the factory contract ("croncat_factory.wasm")
store "artifacts/croncat_factory.wasm"
sleep 2
# Initialize and retrieve the address of the factory contract
instantiate_hash=$(extract_txhash elysd tx wasm instantiate $latest_code_id '{}' --from treasury --gas-prices 0.025uelys --gas auto --gas-adjustment 1.3 -b sync --chain-id=elystestnet-1 -y --admin $(elysd keys show treasury -aa) --label "CronCat-factory-alpha" --keyring-backend=test --amount 50000000uelys)
sleep 2
CRONCAT_FACTORY_ADDR=$(extract_contract_address elysd q tx "$instantiate_hash")
sleep 2


# Store the manager contract ("croncat_manager.wasm")
store "artifacts/croncat_manager.wasm"
sleep 2

#encode the instantate msg into base64
CRONCAT_MANAGER_INST_MSG=$(echo '{"pause_admin":"'$CRONCAT_FACTORY_ADDR'","croncat_tasks_key":["tasks",[0,1]],"croncat_agents_key":["agents",[0,1]]}' | base64 | tr -d '\n')

#set up the deploy msg for the manager contract
CRONCAT_FACTORY_DEPLOY_MANAGER=$(echo '{"deploy":{"kind":"manager","module_instantiate_info":{"code_id":'$latest_code_id',"version":[0,1],"commit_id":"ffb34d716a056898683829a7f6d8ea89d1227961","checksum":"229f1a91efdac64ce3271aa7d868baa85d7589521b9a9c0f9e816b13cb2bd049","changelog_url":"https://example.com/lucky","schema":"https://croncat-schema.example.com/version-0-1","msg":"'$CRONCAT_MANAGER_INST_MSG'","contract_name":"manager"}}}')

#the factory contract should deploy the manager contract 
CRONCAT_MANAGER_HASH=$(extract_txhash elysd tx wasm execute $CRONCAT_FACTORY_ADDR $CRONCAT_FACTORY_DEPLOY_MANAGER --from treasury --amount 1uelys  --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y --keyring-backend=test --chain-id=elystestnet-1)
sleep 2
CRONCAT_MANAGER_ADDR=$(elysd q tx $CRONCAT_MANAGER_HASH  | yq eval '.events[] | select(.type == "instantiate").attributes[] | select(.key == "_contract_address").value')


store "artifacts/croncat_agents.wasm"
sleep 2
CRONCAT_AGENT_INST_MSG=$(echo '{"pause_admin":"'$CRONCAT_FACTORY_ADDR'",
"croncat_manager_key": ["manager",[0,1]],"croncat_tasks_key":["tasks",[0,1]], "public_registration":true}' | base64| tr -d '\n')
CRONCAT_FACTORY_DEPLOY_AGENTS=$(echo '{"deploy":{"kind":"agents","module_instantiate_info":{"code_id":'$latest_code_id',"version":[0,1],"commit_id":"ffb34d716a056898683829a7f6d8ea89d1227961","checksum":"5c610b033df34ef75a252247cd5d5926e28edc222174c5ad49177d2efbeaeb3f","changelog_url":"https://example.com/lucky","schema":"https://croncat-schema.example.com/version-0-1","msg":"'$CRONCAT_AGENT_INST_MSG'","contract_name":"agents"}}}')
CRONCAT_AGENT_HASH=$(extract_txhash elysd tx wasm exec $CRONCAT_FACTORY_ADDR $CRONCAT_FACTORY_DEPLOY_AGENTS --from treasury --amount 1uelys --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y --keyring-backend=test --chain-id=elystestnet-1)
sleep 2
CRONCAT_AGENT_ADDR=$(elysd q tx $CRONCAT_AGENT_HASH  | yq eval '.events[] | select(.type == "instantiate").attributes[] | select(.key == "_contract_address").value')
sleep 2

store "artifacts/croncat_tasks.wasm"
sleep 2
CRONCAT_TASKS_INST_MSG=$(echo '{"pause_admin":"'$CRONCAT_FACTORY_ADDR'","croncat_manager_key": ["manager",[0,1]],"croncat_agents_key":["agents",[0,1]], "chain_name": "elystestnet"}' | base64| tr -d '\n')

CRONCAT_FACTORY_DEPLOY_TASKS=$(echo '{"deploy":{"kind":"tasks","module_instantiate_info":{"code_id":'$latest_code_id',"version":[0,1],"commit_id":"ffb34d716a056898683829a7f6d8ea89d1227961","checksum":"8f95ef9d61226a5797507b2eeb670c623d93e6a118824f5858a78a4149e40cc9","changelog_url":"https://example.com/lucky","schema":"https://croncat-schema.example.com/version-0-1","msg":"'$CRONCAT_TASKS_INST_MSG'","contract_name":"tasks"}}}')
CRONCAT_TASKS_HASH=$(extract_txhash elysd tx wasm exec $CRONCAT_FACTORY_ADDR $CRONCAT_FACTORY_DEPLOY_TASKS --from treasury --amount 1uelys  --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y --keyring-backend=test --chain-id=elystestnet-1)
sleep 2
CRONCAT_TASKS_ADDR=$(elysd q tx $CRONCAT_TASKS_HASH  | yq eval '.events[] | select(.type == "instantiate").attributes[] | select(.key == "_contract_address").value')
sleep 2

store "artifacts/croncat_mod_generic.wasm"
sleep 2

CRONCAT_MOD_GEN_INST_MSG=$(echo '{}' | base64| tr -d '\n')
CRONCAT_MOD_GEN_DEPLOY=$(echo '{"deploy":{"kind":"library","module_instantiate_info":{"code_id":'$latest_code_id',"version":[0,1],"commit_id":"ffb34d716a056898683829a7f6d8ea89d1227961","checksum":"c004610b61b3c64b405658c40b9c845cc9622033ecc4385f03e3db652aad8763","changelog_url":"https://example.com/lucky","schema":"https://croncat-schema.example.com/version-0-1","msg":"'$CRONCAT_MOD_GEN_INST_MSG'","contract_name":"mod_generic"}}}')

CRONCAT_MOD_GEN_HASH=$(extract_txhash elysd tx wasm exec $CRONCAT_FACTORY_ADDR $CRONCAT_MOD_GEN_DEPLOY --from treasury --amount 1uelys  --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y --keyring-backend=test --chain-id=elystestnet-1)
sleep 2

CRONCAT_MOD_GEN_ADDR=$(elysd q tx $CRONCAT_MOD_GEN_HASH  | yq eval '.events[] | select(.type == "instantiate").attributes[] | select(.key == "_contract_address").value')
sleep 2

ADD_TO_WHITE_LIST_MSG=$(echo '{"add_agent_to_whitelist" : {"agent_address"  :"'$(elysd keys show agent123 -aa)'"}}'  | base64 | tr -d '\n')
PROXY_ADD_TO_WHITE_LIST_MSG=$(echo '{"proxy": {"msg": {"execute" : {"contract_addr" :"'$CRONCAT_AGENT_ADDR'", "funds" : [] , "msg" : "'$ADD_TO_WHITE_LIST_MSG'"}}}}')
elysd tx wasm exec $CRONCAT_FACTORY_ADDR "$PROXY_ADD_TO_WHITE_LIST_MSG" --from treasury --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y  --keyring-backend=test --chain-id=elystestnet-1
sleep 2
#make treasury an agent
REGISTER_AGENT_MSG='{"register_agent":{}}'
elysd tx wasm exec $CRONCAT_AGENT_ADDR "$REGISTER_AGENT_MSG"  --from agent123 --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y  --keyring-backend=test --chain-id=elystestnet-1
sleep 2

#create a task
CREATE_TASK_MSG=$(echo '{"create_task": { "task" : {"interval": {"block" : 1},"stop_on_fail": false, "actions" : [{"msg": {"bank": {"send": {"to_address": "'$(elysd keys show seed -aa)'","amount" : [{"amount": "145","denom": "uelys"}]}}}}]}}}')
elysd tx wasm exec $CRONCAT_TASKS_ADDR "$CREATE_TASK_MSG"  --from treasury --amount 5000000uelys --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y  --keyring-backend=test --chain-id=elystestnet-1
sleep 2


# this comment execute the task once
START_TASK=$(echo '{"proxy_call": {}}')
elysd tx wasm exec $CRONCAT_MANAGER_ADDR "$START_TASK" --from agent123 --gas-prices 0.25uelys --gas auto --gas-adjustment 1.3 -b sync -y  --keyring-backend=test --chain-id=elystestnet-1
sleep 2


print_address CRONCAT_FACTORY_ADDR
print_address CRONCAT_MANAGER_ADDR
print_address CRONCAT_AGENT_ADDR
print_address CRONCAT_TASKS_ADDR
print_address CRONCAT_MOD_GEN_ADDR

