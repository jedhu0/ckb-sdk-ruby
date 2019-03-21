RSpec.describe CKB::RPC do
  before do
    skip "not test rpc" if ENV["SKIP_RPC_TESTS"]
  end

  let(:rpc) { CKB::RPC.new }
  let(:type_hash) { "0x8954a4ac5e5c33eb7aa8bb91e0a000179708157729859bd8cf7e2278e1e12980" }

  it "genesis block" do
    result = rpc.genesis_block
    expect(result).not_to be nil
  end

  it "genesis block hash" do
    result = rpc.genesis_block_hash
    expect(result).not_to be nil
  end

  it "get block" do
    genesis_block_hash = rpc.genesis_block_hash
    result = rpc.get_block(genesis_block_hash)
    expect(result).not_to be nil
    expect(result[:header][:hash]).to eq genesis_block_hash
  end

  it "get tip header" do
    result = rpc.get_tip_header
    expect(result).not_to be nil
    expect(result[:number] > 0).to be true
  end

  it "get tip block number" do
    result = rpc.get_tip_block_number
    expect(result > 0).to be true
  end

  it "get cells by type hash" do
    result = rpc.get_cells_by_type_hash(type_hash, 1, 100)
    expect(result).not_to be nil
  end

  it "get transaction" do
    tx = rpc.genesis_block[:"commit_transactions"].first
    result = rpc.get_transaction(tx[:hash])
    expect(result).not_to be nil
    expect(result[:hash]).to eq tx[:hash]
  end

  it "get live cell" do
    cells = rpc.get_cells_by_type_hash(type_hash, 1, 100)
    result = rpc.get_live_cell(cells[0][:out_point])
    expect(result).not_to be nil
  end

  it "send transaction" do
    tx = {
      version: 0,
      deps: [],
      inputs: [],
      outputs: []
    }

    result = rpc.send_transaction(tx)
    expect(result).not_to be nil
  end

  it "local node info" do
    result = rpc.local_node_info
    expect(result).not_to be nil
    expect(result[:addresses].empty?).not_to be true
    expect(result[:node_id].empty?).not_to be true
  end

  it "trace transaction" do
    tx = {
      version: 2,
      deps: [],
      inputs: [],
      outputs: []
    }

    result = rpc.trace_transaction(tx)
    expect(result).not_to be nil
  end

  it "get transaction trace" do
    trace_tx_hash = "0x1704f772f11c4c2fcb543f22cad66adad5a555e21f14c975c37d1d4bad096d47"
    result = rpc.get_transaction_trace(trace_tx_hash)
    expect(result).not_to be nil
  end
end
