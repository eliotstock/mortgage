// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Mortgage.sol";

contract LoanPool {

    using EnumerableSet for EnumerableSet.AddressSet;

    address owner;

    EnumerableSet.AddressSet private lenders;

    mapping (address => uint) lenderContributions;

    EnumerableSet.AddressSet private mortgages;

    // TODO(P3): This could instead be implemented as a getter that iterates
    // over lenderContributions using keys from lenders, and that would only be
    // a call, not a transaction, so gas cost is not a concern.
    uint public totalContributions;

    uint public totalLent;

    // TODO(P3): Don't accept more funds that we can reasonably lend out to
    // borrowers.
    // uint8 constant EXCESS_FUNDS_PERCENT_LIMIT = 110;

    event LoanPoolReceivedFunds(address, uint);
    event NewMortgageApplication(Mortgage);
    event MortgageApproved(Mortgage);

    constructor() {
        owner = msg.sender;
        totalContributions = 0;
        totalLent = 0;
    }

    // Both lenders and mortgage contracts can send ETH here by calling send()
    // or transfer(). Borrowers should not call this contract.
    receive() external payable {
        emit LoanPoolReceivedFunds(msg.sender, msg.value);

        // TODO(P1): Look up the sender and figure out whether they're a
        // lender, a mortgage contract or neither. For now, assume they're a
        // lender.

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
    }

    // An applicant for a mortgage may apply by calling this function from
    // their EOA. We seek not to store any PII on-chain and the applicant
    // should not provide any. Business processes for assessing the applicant's
    // creditworthiness and affordability of the loan will rely on the
    // applicant signing messages with their private key from the public ETH
    // address from which they call this method.
    function applyForMortgage(uint depositAmount, uint loanAmount) external
        returns (Mortgage mortgageAddress) {
        Mortgage m = new Mortgage(address(this), msg.sender, depositAmount,
                loanAmount);
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
        // TODO(P1): This requires Mortgage.receive() to be re-entrant, which
        // smells bad.
        Mortgage m = Mortgage(payable(address(msg.sender)));
        (payable(address(m))).transfer(m.loanAmount());
    }
}
