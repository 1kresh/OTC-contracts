// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract OTC is ReentrancyGuard {
    error ImproperLength();
    error ImproperPublicKey();

    struct Position {
        address creator;
        string text;
        uint256 limit;
        uint256 approvedCounter;
        uint256 startedCounter;
        bool privateChat;
    }

    struct Arbiter {
        uint256[] indexes;
    }
    
    struct Message {
        address sender;
        string text;
    }

    enum Status {
        Created,
        InProcess,
        Rejected,
        Approved
    }

    struct Process {
        address customer;
        address arbiter;
        Message[] messages;
        Status status;
    }

    struct ProcessPointer {
        uint256 positionIndex;
        uint256 processIndex;
    }

    Position[] public positions;
    mapping (address creator => uint256[] positionIndexes) creator_to_positions;

    mapping (uint256 positionIndex => Process[]) processes;
    
    mapping (address arbiter => ProcessPointer[] processPointers) arbiter_to_processPointers;

    modifier onlyCreator(uint256 positionIndex) {
        if (positions[positionIndex].creator != msg.sender) {
            revert();
        }
        _;
    }

    modifier onlyCustomer(ProcessPointer calldata processPointer) {
        if (processes[processPointer.positionIndex][processPointer.processIndex].customer != msg.sender) {
            revert();
        }
        _;
    }

    modifier onlyArbiter(ProcessPointer calldata processPointer) {
        if (processes[processPointer.positionIndex][processPointer.processIndex].arbiter != msg.sender) {
            revert();
        }
        _;
    }

    modifier onlyParticipants(ProcessPointer calldata processPointer) {
        Process storage process = processes[processPointer.positionIndex][processPointer.processIndex];
        if (msg.sender != process.customer && msg.sender != process.arbiter && msg.sender != positions[processPointer.positionIndex].creator) {
            revert();
        }
        _;
    }

    function createPosition(string calldata text, uint256 limit, bool privateChat) external {
        
    }

    function createProcess(uint256 positionIndex, address arbiter) external {
        
    }

    function startProcess(ProcessPointer calldata processPointer) external {

    }

    function sendMessage(ProcessPointer calldata processPointer, string calldata text) external {

    }
}
