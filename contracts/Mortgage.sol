// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./LoanPool.sol";

contract Mortgage {

    enum State {
        Applied,
        Approved,
        DepositReceived,
        InGoodStanding,
        InArrears,
        InForeclosure,
        BadDebt
    }

    address public loanPool;
    address public borrower;
    address public propertyVendor;
    uint public depositAmount;
    uint public loanAmount;
    State public state;

    event MortgageReceivedDeposit(address, uint);
    event MortgageReceivedFunding(address, uint);
    event MortgageReceivedRepayment(address, uint);

    constructor(address _loanPool, address _borrower, address _propertyVendor,
            uint _depositAmount, uint _loanAmount) {
        loanPool = _loanPool;
        borrower = _borrower;
        propertyVendor = _propertyVendor;
        depositAmount = _depositAmount;
        loanAmount = _loanAmount;
        state = State.Applied;
    }

    function approve() public {
        state = State.Approved;
    }

    function sendDeposit() external payable {
        emit MortgageReceivedDeposit(msg.sender, msg.value);

        require(msg.sender == borrower, 'Borrower only');

        require(state == State.Approved, 'Mortgage not in Approved state');

        // Check the amount is greater than or equal to the required
        // deposit.
        
        // TODO(P3): We don't support paying the deposit in multiple
        // transactions yet, but we should so that a borrower can test
        // they have the right address with a small amount first.
        require(msg.value >= depositAmount, 'Insufficent deposit');

        state = State.DepositReceived;

        LoanPool l = LoanPool(payable(address(loanPool)));

        // This will call back to sendFunding().
        l.notifyDepositReceived();
    }

    function sendFunding() external payable {
        emit MortgageReceivedFunding(msg.sender, msg.value);

        require(msg.sender == loanPool, 'Loan pool only');

        require(state == State.DepositReceived,
            'Mortgage not in DepositReceived state');
        
        uint amount = msg.value + depositAmount;

        // Learning note: I'm surprised this works. We're able to send funds on
        // before the execution of the receiving function completes.
        bool ok = payable(propertyVendor).send(amount);

        if (!ok) {
            revert('Unable to forward funds to vendor');
        }
    }

    function sendRepayment() external payable {
        emit MortgageReceivedRepayment(msg.sender, msg.value);

        require(msg.sender == borrower, 'Borrower only');

        require(state == State.InGoodStanding || state == State.InArrears
            || state == State.InForeclosure, 'Wrong state');

        // TODO(P1): Send the repayment on to the loan pool in full.
    }

}
