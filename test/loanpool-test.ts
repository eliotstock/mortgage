import { ethers, waffle } from 'hardhat';
import { expect } from 'chai';
import { Contract, ContractFactory, ContractReceipt, Signer } from 'ethers';

describe('LoanPool', function() {
  // LoanPool contract
  let loanPool: Contract;

  // EOAs
  let owner: Signer;
  let lender: Signer;
  let borrower: Signer;
  let propertyVendor: Signer;

  // Amounts
  const contribAmount = ethers.utils.parseEther('9');
  const propertyValue = ethers.utils.parseEther('9');
  const loanAmount = ethers.utils.parseEther('7');
  const depositAmount = ethers.utils.parseEther('2');
  const insufficientDepositAmount = ethers.utils.parseEther('1');
  const repaymentAmount = ethers.utils.parseEther('0.3');
  const highGasLimit = ethers.utils.parseUnits('12450000');

  before(async () => {
    [owner, lender, borrower, propertyVendor] = await ethers.getSigners();

    const LoanPool = await ethers.getContractFactory('LoanPool');
    loanPool = await LoanPool.deploy();

    await loanPool.deployed();
  });

  it('Should allow a lender to add some funds to the loan pool', async () => {
    expect(await loanPool.getTotalLent()).to.equal(0);
    expect(await loanPool.getTotalContributions()).to.equal(0);

    const tx = await lender.sendTransaction({to: loanPool.address,
        value: contribAmount});
    expect(tx).to.not.be.null;

    expect(await loanPool.getTotalContributions()).to.equal(contribAmount);
  });

  it('Should create a new mortgage contract when a borrower applies',
    async () => {
    // Borrowers apply for mortgages
    loanPool = loanPool.connect(borrower);
    const tx = await loanPool.applyForMortgage(depositAmount, loanAmount,
      propertyVendor.getAddress());
    expect(tx).to.not.be.null;

    // Wait for the next block with the transaction in it.
    let receipt: ContractReceipt = await tx.wait();
    const mortgageAddr = receipt.events?.[0]?.args?.[0];

    const Mortgage = await ethers.getContractFactory('Mortgage');
    const mortgage = await Mortgage.attach(mortgageAddr);

    // 0: State.Applied
    expect(await mortgage.getState()).equals(0);
  });

  it('Should allow only the owner to approve applied mortgages',
    async () => {
    const applyTx = await loanPool.connect(borrower)
      .applyForMortgage(depositAmount, loanAmount,
      propertyVendor.getAddress());

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
    expect(await mortgage.getState()).equals(1);
  });

  it('Borrower of approved mortgage can send deposit, mortgage is funded and'
    + ' vendor is paid',
    async () => {
      // Apply
      let applyReceipt: ContractReceipt = await (
        await loanPool.connect(borrower)
        .applyForMortgage(depositAmount, loanAmount,
        propertyVendor.getAddress())).wait();
      const mortgageAddr = applyReceipt.events?.[0]?.args?.[0];

      // Approve
      await loanPool.connect(owner).approveMortgage(mortgageAddr);

      // Check vendor balance before mortgage funded
      const vendorBalanceBefore = await propertyVendor.getBalance();

      // Pay deposit
      const Mortgage = await ethers.getContractFactory('Mortgage');
      const mortgage = await Mortgage.attach(mortgageAddr);
      const tx = await mortgage.connect(borrower)
        .sendDeposit({value: depositAmount});
      expect(tx).to.not.be.null;

      // 2: State.DepositReceived
      expect(await mortgage.getState()).equals(2);

      // Balance has moved from loan pool to mortgage contract.
      expect(await loanPool.getTotalLent()).to.equal(loanAmount);

      // Property vendor has been paid.
      const vendorBalanceAfter = await propertyVendor.getBalance();
      const delta = (vendorBalanceAfter).sub(vendorBalanceBefore);
      expect(delta).to.equal(propertyValue);
    });

    it('Borrower of approved mortgage must send whole deposit',
    async () => {
      // Apply
      let applyReceipt: ContractReceipt = await (
        await loanPool.connect(borrower)
        .applyForMortgage(depositAmount, loanAmount,
        propertyVendor.getAddress())).wait();
      const mortgageAddr = applyReceipt.events?.[0]?.args?.[0];

      // Approve
      await loanPool.connect(owner).approveMortgage(mortgageAddr);

      // Pay only part of the deposit
      const Mortgage = await ethers.getContractFactory('Mortgage');
      const mortgage = await Mortgage.attach(mortgageAddr);
      await expect(mortgage.sendDeposit({value: insufficientDepositAmount}))
        .to.be.reverted;

      // 1: State.Approved
      expect(await mortgage.getState()).equals(1);
    });

    it('Repayments are passed on to the loan pool', async () => {
      // Apply
      let applyReceipt: ContractReceipt = await (
        await loanPool.connect(borrower)
        .applyForMortgage(depositAmount, loanAmount,
        propertyVendor.getAddress())).wait();
      const mortgageAddr = applyReceipt.events?.[0]?.args?.[0];

      // Approve
      await loanPool.connect(owner).approveMortgage(mortgageAddr);

      // Pay deposit
      const Mortgage = await ethers.getContractFactory('Mortgage');
      const mortgage = await Mortgage.attach(mortgageAddr);

      // TODO: Fix error:

      // InvalidInputError: sender doesn't have enough funds to send tx. The
      // upfront cost is: 99600000000000002000000000000000000 and the sender's
      // account only has: 9997957221152000000000

      // Cost:    99_600_000_000_000_002_000_000_000_000_000_000 (about 100 *
      // 10^15 ETH) - why so high?
      // Balance:                  9_997_957_221_152_000_000_000 (about 1K ETH)

      // 2_000_000_000_000_000_000 (2 ETH)
      console.log('depositAmount: ', depositAmount.toString());

      const tx = await mortgage.connect(borrower)
        .sendDeposit({value: depositAmount, gasLimit: highGasLimit});

      // Make the first repayment
      // mortgage.sendRepayment({value: repaymentAmount});
    });
});
