// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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

    address public borrower;
    uint public loanAmount;
    State public state;

    constructor(address _borrower, uint _loanAmount) {
        borrower = _borrower;
        loanAmount = _loanAmount;
        state = State.Applied;
    }

    function approve() public {
        state = State.Approved;
    }

}
