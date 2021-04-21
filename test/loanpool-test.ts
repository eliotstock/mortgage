import { ethers, waffle } from 'hardhat';
import { expect } from 'chai';
import { Contract, ContractFactory, ContractReceipt, Signer } from 'ethers';

describe('LoanPool', function() {
  // LoanPool contract
  let loanPool: Contract;

  // Accounts
  let owner: Signer;
  let lender: Signer;
  let borrower: Signer;

  // Amounts
  const contribAmount = ethers.utils.parseEther('9');
  const loanAmount = ethers.utils.parseEther('7');

  before(async () => {
    [owner, lender, borrower] = await ethers.getSigners();

    const LoanPool = await ethers.getContractFactory('LoanPool');
    loanPool = await LoanPool.deploy();

    await loanPool.deployed();
  });

  it('Should allow a lender to add some funds to the loan pool', async () => {
    expect(await loanPool.totalLent()).to.equal(0);
    expect(await loanPool.totalContributions()).to.equal(0);

    const tx = await lender.sendTransaction({to: loanPool.address,
        value: contribAmount});
    expect(tx).to.not.be.null;

    expect(await loanPool.totalContributions()).to.equal(contribAmount);
  });

  it('Should create a new mortgage contract when a borrower applies',
    async () => {
    // Event not fired:
    // loanPool.on('NewMortgageApplication', () => {
    //   console.log('NewMortgageApplication event');
    // });

    const tx = await loanPool.applyForMortgage(loanAmount);
    expect(tx).to.not.be.null;
    // console.log("tx: ", tx);

    // Wait for the next block with the transaction in it.
    let receipt: ContractReceipt = await tx.wait();
    // console.log(receipt);
    // console.log(receipt.events?.filter((x) => {return x.event == 'NewMortgageApplication'}));
    // console.log("tx: ", tx);
    const mortgageAddr = receipt.events?.[0]?.args?.[0];
    // console.log('mortgageAddr: ', mortgageAddr);

    const Mortgage = await ethers.getContractFactory('Mortgage');
    const mortgage = await Mortgage.attach(mortgageAddr);
    // console.log('mortgage: ', mortgage);
    // console.log('mortgage state: ', await mortgage.state());

    // 0: State.Applied
    expect(await mortgage.state()).equals(0);
  });
});
