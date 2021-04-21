import { ethers, waffle } from 'hardhat';
import { expect } from "chai";

describe('LoanPool', function() {
  it('Should allow lenders to add some funds to the loan pool', async () => {
    const LoanPool = await ethers.getContractFactory('LoanPool');
    const loanPool = await LoanPool.deploy();

    await loanPool.deployed();
    expect(await loanPool.totalLent()).to.equal(0);
    expect(await loanPool.totalContributions()).to.equal(0);

    const [owner, lender, borrower] = await ethers.getSigners();
    const loanAmount = ethers.utils.parseEther('9');

    console.log("loanPool instance:");
    console.log(loanPool);

    // Fails with:
    //   TypeError: loanPool.connect(...).transfer is not a function
    await loanPool.connect(lender).transfer(loanAmount);
  });
});
