// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { Address } from "openzeppelin-contracts/contracts/utils/Address.sol";

import { IPermit2 } from "src/interfaces/IPermit2.sol";
import { IOTC } from "src/interfaces/IOTC.sol";

contract OTC is Ownable, ReentrancyGuard, IOTC {
    using SafeERC20 for ERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCast for uint256;
    using Address for address;
    using Math for uint256;

    uint256 constant private MAX_BIPS = 10000;
    uint256 constant private ARBITER_BIPS = 500;
    uint256 constant private PROTOCOL_BIPS = 100;

    IPermit2 private immutable PERMIT2;
    address private immutable ZEROX;

    Position[] private _positions;

    mapping (address creator => uint256[] positionIndexes) private _creator_to_positions;

    mapping (uint256 positionIndex => Process[]) private _processes;

    mapping (address participant => ProcessPointer[] processPointers) private _participant_to_processPointers;

    EnumerableSet.AddressSet private _whitelisted_tokens;

    mapping (address token => uint256 amount) _fees;

    error Unauthorized();
    error NotWhitelisted();
    error ImproperLimit();
    error ImproperParticipants();
    error Limit();
    error InsufficientAmount();

    modifier onlyCreator(uint256 positionIndex) {
        if (_positions[positionIndex].creator != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyParticipants(ProcessPointer calldata processPointer) {
        Process storage process = _processes[processPointer.positionIndex][processPointer.processIndex];
        if (msg.sender != process.customer && msg.sender != process.arbiter && msg.sender != _positions[processPointer.positionIndex].creator) {
            revert Unauthorized();
        }
        _;
    }

    modifier isWhitelisted(address token) {
        if (!_whitelisted_tokens.contains(token)) {
            revert NotWhitelisted();
        }
        _;
    }

    modifier statusIs(ProcessPointer calldata processPointer, ProcessStatus status) {
        if (_processes[processPointer.positionIndex][processPointer.processIndex].status != status) {
            revert NotWhitelisted();
        }
        _;
    }

    constructor(address permit2, address zerox) {
        PERMIT2 = IPermit2(permit2);
        ZEROX = zerox;
    }

    function getMaxBips() external pure override returns (uint256) {
        return MAX_BIPS;
    }

    function getArbiterBips() external pure override returns (uint256) {
        return ARBITER_BIPS;
    }

    function getProtocolBips() external pure override returns (uint256) {
        return PROTOCOL_BIPS;
    }

    function getPermit2() external view override returns (address) {
        return address(PERMIT2);
    }

    function getZeroX() external view override returns (address) {
        return ZEROX;
    }


    function getPosition(uint256 positionIndex) external view override returns (Position memory position, Token memory token) {
        position = _positions[positionIndex];

        token = Token({
            name: ERC20(position.token).name(),
            symbol: ERC20(position.token).symbol(),
            decimals: ERC20(position.token).decimals(),
            addr: position.token
        });
    }

    function getPositions(uint256 cursor, uint256 amount) external view override returns (Position[] memory positions, Token[] memory tokens, uint256 newCursor) {
        uint256 length = _positions.length;
        if (length == 0) {
            return (positions, tokens, 0);
        }
        if (cursor >= length) {
            return (positions, tokens, length);
        }

        length -= cursor;
        if (length > amount) {
            length = amount;
        }

        positions = new Position[](length);
        tokens = new Token[](length);
        for (uint256 i; i < length; ++i) {
            positions[i] = _positions[cursor];
            tokens[i] = Token({
                name: ERC20(positions[i].token).name(),
                symbol: ERC20(positions[i].token).symbol(),
                decimals: ERC20(positions[i].token).decimals(),
                addr: positions[i].token
            });
            ++cursor;
        }

        newCursor = cursor;
    }

    function getPositionsByCreator(address creator, uint256 cursor, uint256 amount) external view override returns (Position[] memory positions, Token[] memory tokens, uint256 newCursor) {
        uint256[] storage positionIndexes = _creator_to_positions[creator];

        uint256 length = positionIndexes.length;
        if (length == 0) {
            return (positions, tokens, 0);
        }
        if (cursor >= length) {
            return (positions, tokens, length);
        }

        length -= cursor;
        if (length > amount) {
            length = amount;
        }

        positions = new Position[](length);
        tokens = new Token[](length);
        for (uint256 i; i < length; ++i) {
            positions[i] = _positions[positionIndexes[cursor]];
            tokens[i] = Token({
                name: ERC20(positions[i].token).name(),
                symbol: ERC20(positions[i].token).symbol(),
                decimals: ERC20(positions[i].token).decimals(),
                addr: positions[i].token
            });
            ++cursor;
        }

        newCursor = cursor;
    }

    function getProcess(ProcessPointer calldata processPointer) external view override returns (Position memory position, Token memory positionToken, Process memory process, Token memory processToken) {
        position = _positions[processPointer.positionIndex];
        positionToken = Token({
            name: ERC20(position.token).name(),
            symbol: ERC20(position.token).symbol(),
            decimals: ERC20(position.token).decimals(),
            addr: position.token
        });
        process = _processes[processPointer.positionIndex][processPointer.processIndex];
        processToken = Token({
            name: ERC20(process.token).name(),
            symbol: ERC20(process.token).symbol(),
            decimals: ERC20(process.token).decimals(),
            addr: process.token
        });
    }

    function getProcesses(uint256 positionIndex, uint256 cursor, uint256 amount) external view override returns (Position memory position, Token memory positionToken, Process[] memory processes, Token[] memory processTokens, uint256 newCursor) {
        position = _positions[positionIndex];
        positionToken = Token({
            name: ERC20(position.token).name(),
            symbol: ERC20(position.token).symbol(),
            decimals: ERC20(position.token).decimals(),
            addr: position.token
        });

        Process[] storage processes_ = _processes[positionIndex];
        
        uint256 length = processes_.length;
        if (length == 0) {
            return (position, positionToken, processes, processTokens, 0);
        }
        if (cursor >= length) {
            return (position, positionToken, processes, processTokens, length);
        }

        length -= cursor;
        if (length > amount) {
            length = amount;
        }

        processes = new Process[](length);
        processTokens = new Token[](length);
        for (uint256 i; i < length; ++i) {
            processes[i] = processes_[cursor];
            processTokens[i] = Token({
                name: ERC20(processes[i].token).name(),
                symbol: ERC20(processes[i].token).symbol(),
                decimals: ERC20(processes[i].token).decimals(),
                addr: processes[i].token
            });
            ++cursor;
        }

        newCursor = cursor;
    }

    function getProcessesByPaticipant(address participant, uint256 cursor, uint256 amount) external view override returns (Position[] memory positions, Token[] memory positionTokens, Process[] memory processes, Token[] memory processTokens, uint256 newCursor) {
        ProcessPointer[] storage participant_to_processPointers_ = _participant_to_processPointers[participant];

        uint256 length = participant_to_processPointers_.length;
        if (length == 0) {
            return (positions, positionTokens, processes, processTokens, 0);
        }
        if (cursor >= length) {
            return (positions, positionTokens, processes, processTokens, length);
        }

        length -= cursor;
        if (length > amount) {
            length = amount;
        }

        ProcessPointer memory processPointer;
        positions = new Position[](length);
        positionTokens = new Token[](length);
        processes = new Process[](length);
        processTokens = new Token[](length);
        for (uint256 i; i < length; ++i) {
            processPointer = participant_to_processPointers_[cursor];
            positions[i] = _positions[processPointer.positionIndex];
            positionTokens[i] = Token({
                name: ERC20(positions[i].token).name(),
                symbol: ERC20(positions[i].token).symbol(),
                decimals: ERC20(positions[i].token).decimals(),
                addr: positions[i].token
            });
            processes[i] = _processes[processPointer.positionIndex][processPointer.processIndex];
            processTokens[i] = Token({
                name: ERC20(processes[i].token).name(),
                symbol: ERC20(processes[i].token).symbol(),
                decimals: ERC20(processes[i].token).decimals(),
                addr: processes[i].token
            });
            ++cursor;
        }

        newCursor = cursor;
    }

    function whitelistedTokens() external view override returns (Token[] memory tokens) {
        address[] memory addrs = _whitelisted_tokens.values();

        uint256 length = addrs.length;
        tokens = new Token[](length);
        address addr;
        for (uint256 i; i < length; ++i) {
            addr = addrs[i];
            tokens[i] = Token({
                name: ERC20(addr).name(),
                symbol: ERC20(addr).symbol(),
                decimals: ERC20(addr).decimals(),
                addr: addr
            });
        }
    }

    function createPosition(string calldata text, uint256 limit, address token, uint256 amount, bool privateChat) isWhitelisted(token) nonReentrant external override {
        if (limit == 0) {
            revert ImproperLimit();
        }

        uint256 id = _positions.length;
        _positions.push(Position({
            creator: msg.sender,
            text: text,
            limit: limit,
            startedCounter: 0,
            token: token,
            amount: amount,
            privateChat: privateChat,
            positionIndex: id
        }));
        _creator_to_positions[msg.sender].push(id);
    }

    function createProcess(uint256 positionIndex, address arbiter, address token) isWhitelisted(token) nonReentrant external override {
        Position storage position = _positions[positionIndex];
        Process[] storage processes = _processes[positionIndex];

        address creator = position.creator;
        if (creator == msg.sender || creator == arbiter || msg.sender == arbiter) {
            revert ImproperParticipants();
        }

        uint256 id = processes.length;
        ProcessPointer memory processPointer = ProcessPointer({
            positionIndex: positionIndex,
            processIndex: id
        });
        Process storage process = processes.push();
        process.customer = msg.sender;
        process.arbiter = arbiter;
        process.token = token;
        process.processPointer = processPointer;
        
        _participant_to_processPointers[msg.sender].push(processPointer);
        if (arbiter != address(0)) {
            _participant_to_processPointers[arbiter].push(processPointer);
        }
    }

    function sendMessage(ProcessPointer calldata processPointer, string calldata text) onlyParticipants(processPointer) nonReentrant external override {
        Process storage process = _processes[processPointer.positionIndex][processPointer.processIndex];

        process.messages.push(Message({
            sender: msg.sender,
            text: text
        }));
    }

    function startProcess(ProcessPointer calldata processPointer, uint160 amount, bytes calldata data) onlyCreator(processPointer.positionIndex) statusIs(processPointer, ProcessStatus.Created) nonReentrant external override {
        Position storage position = _positions[processPointer.positionIndex];
        Process storage process = _processes[processPointer.positionIndex][processPointer.processIndex];
        
        uint256 startedProcesses = position.startedCounter + 1;
        if (startedProcesses > position.limit) {
            revert Limit();
        }
        position.startedCounter = startedProcesses;

        address customer = process.customer;
        address positionToken = position.token;
        uint256 positionAmount = position.amount;
        address processToken = process.token;
        uint256 delta;
        uint256 tokenInbalanceBefore;
        if (amount != 0) {
            uint256 balanceBefore = ERC20(processToken).balanceOf(address(this));
            tokenInbalanceBefore = balanceBefore;
            PERMIT2.transferFrom(customer, address(this), amount, processToken);
            uint256 balanceAfter = ERC20(processToken).balanceOf(address(this));

            if (processToken != positionToken) {
                balanceBefore = ERC20(positionToken).balanceOf(address(this)); 
                ERC20(processToken).safeIncreaseAllowance(ZEROX, balanceAfter - balanceBefore);
                ZEROX.functionCall(data);
                ERC20(processToken).safeDecreaseAllowance(ZEROX, ERC20(processToken).allowance(address(this), ZEROX));
                balanceAfter = ERC20(positionToken).balanceOf(address(this));
            }

            delta = balanceAfter - balanceBefore;
        }
        
        uint256 arbiterFees;
        if (process.arbiter != address(0)) {
            arbiterFees = positionAmount.mulDiv(ARBITER_BIPS, MAX_BIPS);
        }
        uint256 protocolFees = positionAmount.mulDiv(PROTOCOL_BIPS, MAX_BIPS);
        uint256 neededAmount = positionAmount + arbiterFees + protocolFees;
        if (delta < neededAmount) {
            revert InsufficientAmount();
        }
        
        process.status = ProcessStatus.InProgress;


        uint256 toReturn = delta - neededAmount;
        if (toReturn != 0) {
            ERC20(positionToken).safeTransfer(customer, toReturn);
        }

        toReturn = ERC20(processToken).balanceOf(address(this)) - tokenInbalanceBefore;
        if (toReturn != 0) {
            ERC20(processToken).safeTransfer(customer, toReturn);
        }
    }

    function finishProcess(ProcessPointer calldata processPointer, bool approved) external statusIs(processPointer, ProcessStatus.InProgress) override {
        Position storage position = _positions[processPointer.positionIndex];
        Process storage process = _processes[processPointer.positionIndex][processPointer.processIndex];

        address customer = process.customer;
        address arbiter = process.arbiter;
        if (arbiter == address(0)) {
            if (msg.sender != customer) {
                revert Unauthorized();
            }
        } else {
            if (msg.sender != arbiter) {
                revert Unauthorized();
            }
        }

        address positionToken = position.token;
        uint256 positionAmount = position.amount;
        uint256 protocolFees = positionAmount.mulDiv(PROTOCOL_BIPS, MAX_BIPS);
        if (approved) {
            _fees[positionToken] += protocolFees;
            process.status = ProcessStatus.Approved;

            if (positionAmount != 0) {
                ERC20(positionToken).safeTransfer(position.creator, positionAmount);
            }
        } else {
            process.status = ProcessStatus.Rejected;
            position.startedCounter -= 1;

            {
                uint256 toReturn = positionAmount + protocolFees;
                if (toReturn != 0) {
                    ERC20(positionToken).safeTransfer(customer, toReturn);
                }
            }
        }

        if (arbiter != address(0)) {
            uint256 arbiterFees = positionAmount.mulDiv(ARBITER_BIPS, MAX_BIPS);
            if (arbiterFees != 0) {
                ERC20(positionToken).safeTransfer(arbiter, arbiterFees);
            }
        }
    }

    function addToken(address token) onlyOwner external override {
        if (!_whitelisted_tokens.add(token)) {
            revert NotWhitelisted();
        }
    }

    function removeToken(address token) onlyOwner external override {
        if (!_whitelisted_tokens.remove(token)) {
            revert NotWhitelisted();
        }
    }
    
    function withdrawFees(address token) onlyOwner nonReentrant external override {
        ERC20(token).safeTransfer(msg.sender, _fees[token]);
        _fees[token] = 0;
    }
}
