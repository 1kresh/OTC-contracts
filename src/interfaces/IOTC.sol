// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IOTC {
    error ImproperLength();
    error ImproperPublicKey();

    enum PositionType {
        Sell,
        Buy
    }

    struct Position {
        address creator;
        PositionType type_;
        string text;
        uint256 limit;
        uint256 startedCounter;
        address token;
        uint256 amount;
        bool privateChat;
        uint256 positionIndex;
    }
    
    struct Message {
        address sender;
        string text;
        bool isPrivate;
    }

    enum ProcessStatus {
        Created,
        InProgress,
        Rejected,
        Approved
    }

    struct Process {
        address customer;
        address arbiter;
        address token;
        Message[] messages;
        ProcessStatus status;
        ProcessPointer processPointer;
    }

    struct ProcessPointer {
        uint256 positionIndex;
        uint256 processIndex;
    }

    struct Token {
        string name;
        string symbol;
        uint256 decimals;
        address addr;
    }

    function getMaxBips() external pure returns (uint256 maxBips);

    function getArbiterBips() external pure returns (uint256 arbiterBips);

    function getProtocolBips() external pure returns (uint256 protocolBips);

    function getPermit2() external view returns (address permit2);
    
    function getZeroX() external view returns (address zerox);


    function getPosition(uint256 positionIndex) external view returns (Position memory position, Token memory token);
    
    function getPositions(uint256 start, uint256 amount) external view returns (Position[] memory positions, Token[] memory tokens, uint256 newCursor);

    function getPositionsByCreator(address creator, uint256 start, uint256 amount) external view returns (Position[] memory positions, Token[] memory tokens, uint256 newCursor);
    
    function getProcess(ProcessPointer calldata processPointer) external view returns (Position memory position, Token memory positionToken, Process memory process, Token memory processToken);

    function getProcesses(uint256 positionIndex, uint256 start, uint256 amount) external view returns (Position memory position, Token memory positionToken, Process[] memory processes, Token[] memory processTokens, uint256 newCursor);

    function getProcessesByPaticipant(address participant, uint256 cursor, uint256 amount) external view returns (Position[] memory positions, Token[] memory positionTokens, Process[] memory processes, Token[] memory processTokens, uint256 newCursor);

    function whitelistedTokens() external view returns (Token[] memory tokens);


    function createPosition(PositionType type_, string calldata text, uint256 limit, address token, uint256 amount, bool privateChat) external;

    function createProcess(uint256 positionIndex, address arbiter, address token) external;

    function startProcess(ProcessPointer calldata processPointer, uint160 amount, bytes calldata data) external;

    function sendMessage(ProcessPointer calldata processPointer, string calldata text, bool isPrivate) external;

    function finishProcess(ProcessPointer calldata processPointer, bool approved) external;

    function addToken(address token) external;

    function removeToken(address token) external;

    function withdrawFees(address token) external;
}
