defmodule EVM.Refunds do
  @type t :: EVM.val()
  alias EVM.{
    ExecEnv,
    MachineCode,
    MachineState,
    Operation,
    SubState
  }

  # Refund given (added into refund counter) when the storage value is set to zero from non-zero.
  @storage_refund 15000
  # Refund given (added into refund counter) for destroying an account.
  @selfdestruct_refund 24000

  @doc """
  Returns the refund amount given a cycle of the VM.

  ## Examples

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>  account_interface: account_interface,
      ...>  machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5,4)
      iex> machine_state = %EVM.MachineState{stack: [5 , 0]}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(machine_state, sub_state, exec_env)
      15000
  """
  @spec refund(MachineState.t(), SubState.t(), ExecEnv.t()) :: t | nil
  def refund(machine_state, sub_state, exec_env) do
    operation = MachineCode.current_operation(machine_state, exec_env)
    inputs = Operation.inputs(operation, machine_state)
    refund(operation.sym, inputs, machine_state, sub_state, exec_env) || 0
  end

  @doc """
  Returns the refund amount based on current opcode and state or nil if no refund is applicable.

  ## Examples

      iex> address = 0x0000000000000000000000000000000000000001
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>   address: address,
      ...>   machine_code: machine_code,
      ...> }
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(:selfdestruct, [], machine_state, sub_state, exec_env)
      24000

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>  account_interface: account_interface,
      ...>  machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5,4)
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(:sstore, [5, 0], machine_state, sub_state, exec_env)
      15000
  """

  # `SELFDESTRUCT` operations produce a refund if the address has not already been suicided.
  def refund(:selfdestruct, _args, _machine_state, sub_state, exec_env) do
    if exec_env.address not in sub_state.selfdestruct_list do
      @selfdestruct_refund
    end
  end

  # `SSTORE` operations produce a refund when storage is set to zero from some non-zero value.
  def refund(:sstore, [key, new_value], _machine_state, _sub_state, exec_env) do
    old_value = ExecEnv.get_storage(exec_env, key)

    if old_value != 0 && new_value == 0 do
      @storage_refund
    end
  end

  def refund(_opcode, _stack, _machine_state, _sub_state, _exec_env), do: nil
end
