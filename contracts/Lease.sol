// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

contract Lease is Arbitrable, IEAS {
    // how to have the contract save payments for each estate
    mapping (bytes32 => ) estateBalance;
    address ieas;

    modifier onlyEstateOwner {
        
    }
    constructor(address _ieas) IEAS(_ieas){
        ieas = _ieas;
    }

    function createSchema()  returns (bytes32) {
        
    }

    function createLease()  returns () {
        
    }

    function attestLease()  returns () {
        
    }

    function revokeLease()  returns () {
        
    }

    function fundLease()  returns () {
        
    }

    function concludeLease()  returns () {
        
    }

    function disputeLease()  returns () {
        
    }

    function withdrawLeasePayments(string estateId) onlyEstateOwner returns () {
        
    }

    function getLease()  returns () {
        
    }
}