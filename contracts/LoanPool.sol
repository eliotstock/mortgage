// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Mortgage.sol";
import "hardhat/console.sol";

contract LoanPool {

    using EnumerableSet for EnumerableSet.AddressSet;

    address private owner;
    EnumerableSet.AddressSet private lenders;
    mapping (address => uint) private lenderContributions;
    EnumerableSet.AddressSet private mortgages;

    // TODO(P3): This could instead be implemented as a getter that iterates
    // over lenderContributions using keys from lenders, and that would only be
    // a call, not a transaction, so gas cost is not a concern.
    uint private totalContributions;
    uint private totalLent;

    event LoanPoolReceivedFunds(address, uint);
    event NewMortgageApplication(Mortgage);
    event MortgageApproved(Mortgage);

    constructor() {
        owner = msg.sender;
        totalContributions = 0;
        totalLent = 0;
    }

    function getTotalLent() public view returns (uint l) {
        return totalLent;
    }

    function getTotalContributions() public view returns (uint l) {
        return totalContributions;
    }

    // Both lenders and mortgage contracts can send ETH here by calling send()
    // or transfer(). Borrowers should not call this contract.
    receive() external payable {
        require(!mortgages.contains(msg.sender),
            'Mortgages should not send funds here');

        // TODO(P1): Don't have everyone send funds here. Split out separate
        // payable functions for lender and mortgage contract.

        // TODO(P3): Don't accept more funds that we can reasonably lend out to
        // borrowers any time soon.

        // uint256 excessFundsAbs = address(this).balance - totalLent;
        // Avoid division by zero when we're brand new:
        // uint256 excessFundsPercent = (excessFundsAbs / totalLent) * 100;
        // require(excessFundsPercent < EXCESS_FUNDS_PERCENT_LIMIT,
        //         "Sorry, too much. We're full.");

        // Register the lender's contribution to the pool.
        lenders.add(msg.sender);
        lenderContributions[msg.sender] += msg.value;
        totalContributions += msg.value;

        emit LoanPoolReceivedFunds(msg.sender, msg.value);
    }

    // An applicant for a mortgage may apply by calling this function from
    // their EOA. We seek not to store any PII on-chain and the applicant
    // should not provide any. Business processes for assessing the applicant's
    // creditworthiness and affordability of the loan will rely on the
    // applicant signing messages with their private key from the public ETH
    // address from which they call this method.
    function applyForMortgage(uint depositAmount, uint loanAmount,
            address propertyVendor) external
        returns (Mortgage mortgageAddress) {
        // TODO(P3): Can we require that the caller is an EOA and not a
        // contract?
        // TODO(P3): Can an existing lender also apply for a mortgage?
        Mortgage m = new Mortgage(address(this), msg.sender, propertyVendor,
            depositAmount, loanAmount);

        mortgages.add(address(m));

        // The JS tests rely on this event in order to get the Mortgage
        // instance.
        emit NewMortgageApplication(m);

        return m;
    }

    function approveMortgage(address mortgageAddress) external {
        require(msg.sender == owner, 'Owner only');
        
        Mortgage m = Mortgage(payable(address(mortgageAddress)));
        m.approve();

        emit MortgageApproved(m);
    }

    function notifyDepositReceived() external {
        require(mortgages.contains(msg.sender));

        // Send the loan amount to the mortgage contract.
        Mortgage m = Mortgage(payable(address(msg.sender)));

        console.log("m.getLoanAmount():", m.getLoanAmount());

        m.sendFunding{value: m.getLoanAmount()}();
        totalLent += m.getLoanAmount();
    }
}
