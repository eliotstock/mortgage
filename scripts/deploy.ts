import { run, ethers } from "hardhat";

async function main() {
  await run("compile");

  const LoanPool = await ethers.getContractFactory('LoanPool');
  const loanPool = await LoanPool.deploy();

  // const accounts = await ethers.getSigners();
  // console.log("Accounts:", accounts.map(a => a.address));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
