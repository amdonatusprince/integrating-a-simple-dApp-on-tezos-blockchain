//declaring the alias trusted of address type. We will use it for addresses entitled to send tokens
type trusted is address;

//declaring the alias amt (amount) of nat type to store balances
type amt is nat;

(* announcing the alias account of record type. It will store data on users entitled to receive tokens
*)
type account is
  record [
    balance         : amt;
    allowances      : map (trusted, amt);
  ]

(* declaring the type of SC storage. It keeps the overall quantity of tokens and big_map data structure that ensures the connection between user balances and public addresses *)
type storage is
  record [
    totalSupply     : amt;
    ledger          : big_map (address, account);
  ]

(* declaring the alias for the return method that will return operations. In short contracts one can do without it, yet it is easier to describe the return type just once in contracts with several pseudo-entry points and then use it in every function *)
type return is list (operation) * storage

(* declare the empty list noOperations. It will be returned by transfer and approve *)
const noOperations : list (operation) = nil;
(* declaring aliases of input params for each main function of FA 1.2. *)

// transfer function gets the sender’s address, the recipient’s address, and the transaction amount to the input
type transferParams is michelson_pair(address, "from", michelson_pair(address, "to", amt, "value"), "")
// approve gets user address and number of tokens they can send from the SC’s balance
type approveParams is michelson_pair(trusted, "spender", amt, "value")
// getBalance gets the addresses of the user and the proxy contract where it sends balance data
type balanceParams is michelson_pair(address, "owner", contract(amt), "")
// getAllowance gets the user’s address, their SC account data abd the proxy contract
type allowanceParams is michelson_pair(michelson_pair(address, "owner", trusted, "spender"), "", contract(amt), "")
// totalSupply doesn’t use michelson_pair as the first input param is the empty value of unit will be the first anyway after being sorted by Michelson compiler
type totalSupplyParams is (unit * contract(amt))

(* declaring pseudo-entry points: give them a name and assign the type of params described above*)
type entryAction is
  | Transfer of transferParams
  | Approve of approveParams
  | GetBalance of balanceParams
  | GetAllowance of allowanceParams
  | GetTotalSupply of totalSupplyParams

function getAccount (const addr : address; const s : storage) : account is
  block {
      // allowances assigning the variable acct the value of account type: zero balance and empty entry
    var acct : account :=
      record [
        balance    = 0n;
        allowances = (map [] : map (address, amt));
      ];

    (* checking if the storage has the user account: if no, leave acct empty with the previous block’s value; if yes, assign the value from the storage to acct. The function returns the acct value *)
    case s.ledger[addr] of
      None -> skip
    | Some(instance) -> acct := instance
    end;
  } with acct

function getAllowance (const ownerAccount : account; const spender : address; const s : storage) : amt is
  (* if the user has allowed to send a certain amount of tokens, the function assigns the amount to amt. If not, the number of tokens equals zero *)
  case ownerAccount.allowances[spender] of
    Some (amt) -> amt
  | None -> 0n
  end;

function transfer (const from_ : address; const to_ : address; const value : amt; var s : storage) : return is
  block {

    (* call getAccount to assign user account data to senderAccount. Then we use senderAccount to read the user’s balance and permissions*)
    var senderAccount : account := getAccount(from_, s);

    (* checking whether the user has sufficient funds. If not, the VM terminates the contract execution, if yes, it carries on with executing the contract *)
    if senderAccount.balance < value then
      failwith("NotEnoughBalance")
    else skip;

    (* checking if the initiating address can send tokens. If it requests a transfer from someone else’s address, the function asks the real owner for permission. If the initiator and the sender are the same address, the VM carries on with executing the contract  *)
    if from_ =/= Tezos.sender then block {
    (* calling the function getAllowance so that the owner would specify how many tokens they allow to be sent, and assign the value to the constant spenderAllowance *)
      const spenderAllowance : amt = getAllowance(senderAccount, Tezos.sender, s);

    (* if the owner has allowed sending less tokens than specified in the input param, the VM will terminate the contract execution *)
      if spenderAllowance < value then
        failwith("NotEnoughAllowance")
      else skip;

      (* subtracting the transaction amount from the allowed amount *)
      senderAccount.allowances[Tezos.sender] := abs(spenderAllowance - value);
    } else skip;

    (* subtracting the sent tokens from the balance of the sender address *)
    senderAccount.balance := abs(senderAccount.balance - value);

    (* updating the balance record in the sender’s storage *)
    s.ledger[from_] := senderAccount;

    (* once again call getAccount to get or create an account record for the recipient address *)
    var destAccount : account := getAccount(to_, s);

    (* adding the amount of sent tokens to the recipient’s balance *)
    destAccount.balance := destAccount.balance + value;

    (* updating the balance record in the recipient’s storage *)
    s.ledger[to_] := destAccount;

  }
  // returning the empty list of operations and the storage state after the function’s execution
 	with (noOperations, s)
function approve (const spender : address; const value : amt; var s : storage) : return is
  block {

    (* getting the user account data *)
    var senderAccount : account := getAccount(Tezos.sender, s);

    (* getting the current amount of tokens the user opted to send *)
    const spenderAllowance : amt = getAllowance(senderAccount, spender, s);

    if spenderAllowance > 0n and value > 0n then
      failwith("UnsafeAllowanceChange")
    else skip;

    (* introducing the number of tokens newly permitted for spending in the account data *)
    senderAccount.allowances[spender] := value;

    (* updating the SC storage *)
    s.ledger[Tezos.sender] := senderAccount;

  } with (noOperations, s)

function getBalance (const owner : address; const contr : contract(amt); var s : storage) : return is
  block {
      //assigning account data to the constant ownerAccount
    const ownerAccount : account = getAccount(owner, s);
  }
  //returning the account balance to the proxy contract
  with (list [transaction(ownerAccount.balance, 0tz, contr)], s)


function getAllowance (const owner : address; const spender : address; const contr : contract(amt); var s : storage) : return is
  block {
      //getting account data and retrieve the number of tokens allowed for spending therefrom
    const ownerAccount : account = getAccount(owner, s);
    const spenderAllowance : amt = getAllowance(ownerAccount, spender, s);
  } with (list [transaction(spenderAllowance, 0tz, contr)], s)

function getTotalSupply (const contr : contract(amt); var s : storage) : return is
  block {
    skip
  } with (list [transaction(s.totalSupply, 0tz, contr)], s)

function main (const action : entryAction; var s : storage) : return is
  block {
    skip
  } with case action of
    | Transfer(params) -> transfer(params.0, params.1.0, params.1.1, s)
    | Approve(params) -> approve(params.0, params.1, s)
    | GetBalance(params) -> getBalance(params.0, params.1, s)
    | GetAllowance(params) -> getAllowance(params.0.0, params.0.1, params.1, s)
    | GetTotalSupply(params) -> getTotalSupply(params.1, s)
  end;