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
  const depositAmount = ethers.utils.parseEther('2');
  const insufficientDepositAmount = ethers.utils.parseEther('1');

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

    // Borrowers apply for mortgages
    loanPool = loanPool.connect(borrower);
    const tx = await loanPool.applyForMortgage(depositAmount, loanAmount);
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

  it('Should allow only the owner to approve applied mortgages',
    async () => {
    const applyTx = await loanPool.connect(borrower)
      .applyForMortgage(depositAmount, loanAmount);

    let applyReceipt: ContractReceipt = await applyTx.wait();
    const mortgageAddr = applyReceipt.events?.[0]?.args?.[0];

    await expect(loanPool.connect(borrower).approveMortgage(mortgageAddr))
      .to.be.reverted;

    await expect(loanPool.connect(lender).approveMortgage(mortgageAddr))
      .to.be.reverted;

    const approveTx = await loanPool.connect(owner)
      .approveMortgage(mortgageAddr);

    let approveReceipt: ContractReceipt = await approveTx.wait();
    // console.log(approveReceipt);
    let approvedEvent = approveReceipt.events?.[0];
    expect(approvedEvent).to.be.not.null;
    expect(approvedEvent?.event).to.be.equals('MortgageApproved');

    const Mortgage = await ethers.getContractFactory('Mortgage');
    const mortgage = await Mortgage.attach(mortgageAddr);

    // 1: State.Approved
    expect(await mortgage.state()).equals(1);
  });

  it('Borrower of approved mortgage can send deposit',
    async () => {
      // Apply
      let applyReceipt: ContractReceipt = await (
        await loanPool.connect(borrower)
        .applyForMortgage(depositAmount, loanAmount)).wait();
      const mortgageAddr = applyReceipt.events?.[0]?.args?.[0];

      // Approve
      await loanPool.connect(owner).approveMortgage(mortgageAddr);

      // Pay deposit
      const Mortgage = await ethers.getContractFactory('Mortgage');
      const mortgage = await Mortgage.attach(mortgageAddr);
      const tx = await borrower.sendTransaction({to: mortgage.address,
        value: depositAmount});
      expect(tx).to.not.be.null;

      // 2: State.DepositReceived
      expect(await mortgage.state()).equals(2);
    });

    it('Borrower of approved mortgage must send whole deposit',
    async () => {
      // Apply
      let applyReceipt: ContractReceipt = await (
        await loanPool.connect(borrower)
        .applyForMortgage(depositAmount, loanAmount)).wait();
      const mortgageAddr = applyReceipt.events?.[0]?.args?.[0];

      // Approve
      await loanPool.connect(owner).approveMortgage(mortgageAddr);

      // Pay only part of the deposit
      const Mortgage = await ethers.getContractFactory('Mortgage');
      const mortgage = await Mortgage.attach(mortgageAddr);
      await expect(borrower.sendTransaction({to: mortgage.address,
        value: insufficientDepositAmount})).to.be.reverted;

      // 1: State.Approved
      expect(await mortgage.state()).equals(1);
    });
});
