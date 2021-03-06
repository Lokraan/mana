defmodule EVM.Configuration.EIP158 do
  defstruct fallback_config: EVM.Configuration.EIP150.new(),
            exp_byte_cost: 50,
            code_size_limit: 24_577,
            increment_nonce_on_create: true,
            empty_account_value_transfer: true,
            clean_touched_accounts: true

  def new do
    %__MODULE__{}
  end
end

defimpl EVM.Configuration, for: EVM.Configuration.EIP158 do
  alias EVM.Configuration

  @spec contract_creation_cost(Configuration.t()) :: integer()
  def contract_creation_cost(config),
    do: Configuration.contract_creation_cost(config.fallback_config)

  @spec has_delegate_call?(Configuration.t()) :: boolean()
  def has_delegate_call?(config), do: Configuration.has_delegate_call?(config.fallback_config)

  @spec max_signature_s(Configuration.t()) :: atom()
  def max_signature_s(config), do: Configuration.max_signature_s(config.fallback_config)

  @spec fail_contract_creation_lack_of_gas?(Configuration.t()) :: boolean()
  def fail_contract_creation_lack_of_gas?(config),
    do: Configuration.fail_contract_creation_lack_of_gas?(config.fallback_config)

  @spec extcodesize_cost(Configuration.t()) :: integer()
  def extcodesize_cost(config), do: Configuration.extcodesize_cost(config.fallback_config)

  @spec extcodecopy_cost(Configuration.t()) :: integer()
  def extcodecopy_cost(config), do: Configuration.extcodecopy_cost(config.fallback_config)

  @spec balance_cost(Configuration.t()) :: integer()
  def balance_cost(config), do: Configuration.balance_cost(config.fallback_config)

  @spec sload_cost(Configuration.t()) :: integer()
  def sload_cost(config), do: Configuration.sload_cost(config.fallback_config)

  @spec call_cost(Configuration.t()) :: integer()
  def call_cost(config), do: Configuration.call_cost(config.fallback_config)

  @spec selfdestruct_cost(Configuration.t(), keyword()) :: integer()
  def selfdestruct_cost(config, params),
    do: Configuration.selfdestruct_cost(config.fallback_config, params)

  @spec fail_nested_operation_lack_of_gas?(Configuration.t()) :: boolean()
  def fail_nested_operation_lack_of_gas?(config),
    do: Configuration.fail_nested_operation_lack_of_gas?(config.fallback_config)

  @spec exp_byte_cost(Configuration.t()) :: integer()
  def exp_byte_cost(config), do: config.exp_byte_cost

  @spec limit_contract_code_size?(Configuration.t(), integer()) :: boolean()
  def limit_contract_code_size?(config, size), do: size >= config.code_size_limit

  @spec increment_nonce_on_create?(Configuration.t()) :: boolean()
  def increment_nonce_on_create?(config), do: config.increment_nonce_on_create

  @spec empty_account_value_transfer?(Configuration.t()) :: boolean()
  def empty_account_value_transfer?(config), do: config.empty_account_value_transfer

  @spec clean_touched_accounts?(Configuration.t()) :: boolean()
  def clean_touched_accounts?(config), do: config.clean_touched_accounts

  @spec has_revert?(Configuration.t()) :: boolean()
  def has_revert?(config), do: Configuration.has_revert?(config.fallback_config)

  @spec has_static_call?(Configuration.t()) :: boolean()
  def has_static_call?(config), do: Configuration.has_static_call?(config.fallback_config)

  @spec support_variable_length_return_value?(Configuration.t()) :: boolean()
  def support_variable_length_return_value?(config),
    do: Configuration.support_variable_length_return_value?(config.fallback_config)

  @spec has_mod_exp_builtin?(Configuration.t()) :: boolean()
  def has_mod_exp_builtin?(config), do: Configuration.has_mod_exp_builtin?(config.fallback_config)

  @spec has_ec_add_builtin?(Configuration.t()) :: boolean()
  def has_ec_add_builtin?(config), do: Configuration.has_ec_add_builtin?(config.fallback_config)

  @spec has_ec_mult_builtin?(Configuration.t()) :: boolean()
  def has_ec_mult_builtin?(config), do: Configuration.has_ec_mult_builtin?(config.fallback_config)
end
