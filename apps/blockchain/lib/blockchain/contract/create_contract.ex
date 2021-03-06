defmodule Blockchain.Contract.CreateContract do
  @moduledoc """
  Represents a contract creation command,
  as defined in Section 7, Eq.(76) of the Yellow Paper.
  """

  alias Blockchain.Interface.{BlockInterface, AccountInterface}
  alias Block.Header
  alias Blockchain.Contract.Address
  alias Blockchain.Account
  alias EVM.{SubState, Gas}

  defstruct state: %{},
            sender: <<>>,
            originator: <<>>,
            available_gas: 0,
            gas_price: 0,
            endowment: 0,
            init_code: <<>>,
            stack_depth: 0,
            block_header: nil,
            config: EVM.Configuration.Frontier.new()

  @typedoc """
  Yellow Paper Terms:

  - σ: state,
  - s: sender,
  - o: originator,
  - g: available_gas,
  - p: gas_price,
  - v: endowment,
  - i: init_code,
  - e: stack_depth
  """
  @type t :: %__MODULE__{
          state: EVM.state(),
          sender: EVM.address(),
          originator: EVM.address(),
          available_gas: EVM.Gas.t(),
          gas_price: EVM.Gas.gas_price(),
          endowment: EVM.Wei.t(),
          init_code: EVM.MachineCode.t(),
          stack_depth: integer(),
          block_header: Header.t(),
          config: EVM.Configuration.t()
        }

  @spec execute(t()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  def execute(params) do
    sender_account = Account.get_account(params.state, params.sender)
    contract_address = Address.new(params.sender, sender_account.nonce)
    account = Account.get_account(params.state, contract_address)

    if Account.exists?(account) do
      cond do
        account_will_collide?(account) ->
          error(params.state)

        account.nonce == 0 && Account.is_simple_account?(account) &&
            not_in_contract_create_transaction?(params) ->
          new_state =
            increment_nonce_of_touched_account(params.state, params.config, contract_address)

          {:ok, {new_state, params.available_gas, SubState.empty()}}

        true ->
          {:ok, {params.state, 0, SubState.empty()}}
      end
    else
      result = {rem_gas, _, _, output} = create(params, contract_address)

      # From the Yellow Paper:
      # if the execution halts in an exceptional fashion
      # (i.e.  due to an exhausted gas supply, stack underflow, in-
      # valid jump destination or invalid instruction), then no gas
      # is refunded to the caller and the state is reverted to the
      # point immediately prior to balance transfer.
      #
      case output do
        :failed -> error(params.state)
        {:revert, _} -> {:error, {params.state, rem_gas, SubState.empty()}}
        _ -> finalize(result, params, contract_address)
      end
    end
  end

  @spec increment_nonce_of_touched_account(EVM.state(), EVM.Configuration.t(), EVM.address()) ::
          EVM.state()
  defp increment_nonce_of_touched_account(state, config, address) do
    if EVM.Configuration.increment_nonce_on_create?(config) do
      Account.increment_nonce(state, address)
    else
      state
    end
  end

  @spec not_in_contract_create_transaction?(t) :: boolean()
  defp not_in_contract_create_transaction?(params) do
    # params.stack_depth != 0 means that we're not in contract creation transaction
    # because `create` evm instruction should have parameters on the stack that are pushed to it so
    # it never is zero
    params.stack_depth != 0
  end

  @spec account_will_collide?(Account.t()) :: boolean()
  defp account_will_collide?(account) do
    account.nonce > 0 || !Account.is_simple_account?(account)
  end

  @spec error(EVM.state()) :: {:error, EVM.state(), 0, SubState.t()}
  defp error(state) do
    {:error, {state, 0, SubState.empty()}}
  end

  @spec create(t(), EVM.address()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  defp create(params, address) do
    state_with_blank_contract =
      params
      |> init_blank_account(address)
      |> increment_nonce_of_touched_account(params.config, address)

    account_interface = AccountInterface.new(state_with_blank_contract)

    # Create an execution environment for a create contract call.
    # This is defined in Eq.(88), Eq.(89), Eq.(90), Eq.(91), Eq.(92),
    # Eq.(93), Eq.(94) and Eq.(95) of the Yellow Paper.
    exec_env = %EVM.ExecEnv{
      address: address,
      originator: params.originator,
      gas_price: params.gas_price,
      data: <<>>,
      sender: params.sender,
      value_in_wei: params.endowment,
      machine_code: params.init_code,
      stack_depth: params.stack_depth,
      block_interface: BlockInterface.new(params.block_header, state_with_blank_contract.db),
      account_interface: account_interface,
      config: params.config
    }

    EVM.VM.run(params.available_gas, exec_env)
  end

  @spec init_blank_account(t, EVM.address()) :: EVM.state()
  defp init_blank_account(params, address) do
    params.state
    |> Account.put_account(address, %Account{nonce: 0})
    |> Account.transfer!(params.sender, address, params.endowment)
  end

  @spec finalize(
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()},
          t(),
          EVM.address()
        ) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  defp finalize({remaining_gas, accrued_sub_state, exec_env, output}, params, address) do
    state_after_init = exec_env.account_interface.state

    contract_creation_cost = creation_cost(output)
    insufficient_gas = remaining_gas < contract_creation_cost

    cond do
      insufficient_gas && EVM.Configuration.fail_contract_creation_lack_of_gas?(params.config) ->
        {:error, {params.state, 0, SubState.empty()}}

      EVM.Configuration.limit_contract_code_size?(params.config, byte_size(output)) ->
        {:error, {params.state, 0, SubState.empty()}}

      true ->
        resultant_gas =
          if insufficient_gas do
            remaining_gas
          else
            remaining_gas - contract_creation_cost
          end

        resultant_state =
          if insufficient_gas do
            state_after_init
          else
            Account.put_code(state_after_init, address, output)
          end

        sub_state = SubState.add_touched_account(accrued_sub_state, address)

        {:ok, {resultant_state, resultant_gas, sub_state}}
    end
  end

  # Returns the additional cost after creating a new contract.
  # This is defined as Eq.(96) of the Yellow Paper.
  @spec creation_cost(binary()) :: EVM.Wei.t()
  defp creation_cost(output) do
    data_size =
      output
      |> :binary.bin_to_list()
      |> Enum.count()

    data_size * Gas.codedeposit_cost()
  end
end
