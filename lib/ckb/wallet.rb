# frozen_string_literal: true

# rubocop:disable Naming/AccessorMethodName

require "secp256k1"

module CKB
  MIN_CELL_CAPACITY = 40

  class Wallet
    attr_reader :api
    # privkey is a bin string
    attr_reader :privkey

    # @param api [CKB::API]
    # @param privkey [String] hex string
    def initialize(api, privkey)
      raise ArgumentError, "invalid privkey!" unless privkey.instance_of?(String) && privkey.size == 66
      raise ArgumentError, "invalid hex string!" unless CKB::Utils.valid_hex_string?(privkey)

      @api = api
      @privkey = privkey
    end

    def self.random_private_key
      CKB::Utils.bin_to_hex(SecureRandom.bytes(32))
    end

    # @param api [CKB::API]
    # @param privkey_hex [String] hex string
    #
    # @return [CKB::Wallet]
    def self.from_hex(api, privkey)
      new(api, privkey)
    end

    def get_unspent_cells
      to = api.get_tip_block_number
      results = []
      current_from = 1
      while current_from <= to
        current_to = [current_from + 100, to].min
        cells = api.get_cells_by_lock_hash(lock_hash, current_from, current_to)
        results.concat(cells)
        current_from = current_to + 1
      end
      results
    end

    def get_balance
      get_unspent_cells.map { |cell| cell[:capacity] }.reduce(0, &:+)
    end

    def generate_tx(target_address, capacity)
      i = gather_inputs(capacity, MIN_CELL_CAPACITY)
      input_capacities = i.capacities

      outputs = [
        {
          capacity: capacity,
          data: "0x",
          lock: CKB::Utils.generate_lock(api.parse_address(target_address),
                                         api.system_script_cell_hash)
        }
      ]
      if input_capacities > capacity
        outputs << {
          capacity: input_capacities - capacity,
          data: "0x",
          lock: lock
        }
      end

      inputs, witnesses = CKB::Utils.sign_sighash_all_inputs(i.inputs, outputs, privkey, i.pubkeys)

      {
        version: 0,
        deps: [api.system_script_out_point],
        inputs: inputs,
        outputs: outputs,
        witnesses: witnesses
      }
    end

    # @param target_address [String]
    # @param capacity [Integer]
    def send_capacity(target_address, capacity)
      tx = generate_tx(target_address, capacity)
      send_transaction(tx)
    end

    # @param hash_hex [String] "0x..."
    def get_transaction(hash)
      api.get_transaction(hash)
    end

    def block_assembler_config
      args = lock[:args].map do |arg|
        "[#{CKB::Utils.hex_to_bin(arg).bytes.map(&:to_s).join(', ')}]"
      end.join(", ")
      %(
[block_assembler]
binary_hash = "#{lock[:binary_hash]}"
args = [#{args}]
     ).strip
    end

    def address
      api.generate_address(pubkey_blake160)
    end

    private

    def send_transaction(transaction)
      api.send_transaction(transaction)
    end

    def gather_inputs(capacity, min_capacity)
      raise "capacity cannot be less than #{min_capacity}" if capacity < min_capacity

      input_capacities = 0
      inputs = []
      pubkeys = []
      get_unspent_cells.each do |cell|
        input = {
          previous_output: cell[:out_point],
          args: []
        }
        pubkeys << pubkey
        inputs << input
        input_capacities += cell[:capacity]

        break if input_capacities >= capacity && (input_capacities - capacity) >= min_capacity
      end

      raise "Not enough capacity!" if input_capacities < capacity

      OpenStruct.new(inputs: inputs, capacities: input_capacities, pubkeys: pubkeys)
    end

    def pubkey
      CKB::Utils.extract_pubkey(privkey)
    end

    def pubkey_blake160
      CKB::Utils.pubkey_blake160(pubkey)
    end

    def lock_hash
      @lock_hash ||= CKB::Utils.json_script_to_type_hash(lock)
    end

    def lock
      CKB::Utils.generate_lock(pubkey_blake160, api.system_script_cell_hash)
    end
  end
end

# rubocop:enable Naming/AccessorMethodName