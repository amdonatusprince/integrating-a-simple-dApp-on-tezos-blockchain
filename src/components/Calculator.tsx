import React, { useState, Dispatch, SetStateAction } from "react";
import { TezosToolkit, WalletContract } from "@taquito/taquito";

interface CalculatorContractProps {
  contract: WalletContract | any;
  setUserBalance: Dispatch<SetStateAction<any>>;
  Tezos: TezosToolkit;
  userAddress: string;
  setStorage: Dispatch<SetStateAction<number>>;
}

const CalculatorContract = ({ contract, setUserBalance, Tezos, userAddress, setStorage }: CalculatorContractProps) => {
  const [loadingMultiply, setLoadingMultiply] = useState<boolean>(false);
  const [loadingAdd, setLoadingAdd] = useState<boolean>(false);
  const [x, setX] = useState<number>(0);
  const [y, setY] = useState<number>(0);

  const multiply = async (): Promise<void> => {
    setLoadingMultiply(true);
    try {
      // Call multiply entry point of the smart contract with user input values
      const op = await contract.methods.multiply(x, y).send();
      await op.confirmation();
      const newStorage: any = await contract.storage();
      if (newStorage) setStorage(newStorage.toNumber());
      setUserBalance((await Tezos.tz.getBalance(userAddress)).toString()); // Convert to string
    } catch (error) {
      console.log(error);
    } finally {
      setLoadingMultiply(false);
    }
  };
  
  const add = async (): Promise<void> => {
    setLoadingAdd(true);
    try {
      // Call add entry point of the smart contract with user input values
      const op = await contract.methods.add(x, y).send();
      await op.confirmation();
      const newStorage: any = await contract.storage();
      if (newStorage) setStorage(newStorage.toNumber());
      setUserBalance((await Tezos.tz.getBalance(userAddress)).toString()); // Convert to string
    } catch (error) {
      console.log(error);
    } finally {
      setLoadingAdd(false);
    }
  };

  if (!contract && !userAddress) return <div>&nbsp;</div>;
  return (
    <div className="buttons">
      <button className="button" disabled={loadingMultiply} onClick={multiply}>
        {loadingMultiply ? (
          <span>
            <i className="fas fa-spinner fa-spin"></i>&nbsp; Please wait
          </span>
        ) : (
          <span>
            <i className="fas fa-times"></i>&nbsp; Multiply
          </span>
        )}
      </button>
      <button className="button" disabled={loadingAdd} onClick={add}>
        {loadingAdd ? (
          <span>
            <i className="fas fa-spinner fa-spin"></i>&nbsp; Please wait
          </span>
        ) : (
          <span>
            <i className="fas fa-plus"></i>&nbsp; Add
          </span>
        )}
      </button>
      <div id="transfer-inputs">
        <label>Enter a Number (B):</label>
        <input type="number" value={y} onChange={(e) => setY(Number(e.target.value))} />
      </div>
      <div id="transfer-inputs">
        <label>Enter a Number (A):</label>
        <input type="number" value={x} onChange={(e) => setX(Number(e.target.value))} />
      </div>

    </div>
  );
};

export default CalculatorContract;
