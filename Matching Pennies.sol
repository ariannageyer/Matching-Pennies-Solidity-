// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


contract MatchingPennies {
    
    struct Game {
        bytes32 hashedAnswer;
        bool answerA;
        bool answerB;
        bool expiryRevealStarted;
        uint256 expirationPlay;
        uint256 expirationReveal;
    }
    
    mapping(bytes32 => Game) games;
    mapping(address => uint256) payoffsByAddress;
    
    event DepositForGame(address senderAddress, address opponentAddress);
    event Winner(address winnerAddress);
    event Payoff(address player);

    function requestGameCreation(address opponentAddress, bytes32 hashedAnswer) external payable {
        address senderAddress = msg.sender;
        
        require(
            msg.value == 1 ether,
            "Send 1 ETH to play."
        );
        
        emit DepositForGame(senderAddress, opponentAddress);
        
        createGame(senderAddress, opponentAddress, hashedAnswer);
    }
        
    function createGame(address senderAddress, address opponentAddress, bytes32 hashedAnswer) internal {
        bytes32 senderOpponentHash = sha256(abi.encodePacked(senderAddress, opponentAddress));
        
        require(
            !games[senderOpponentHash].expiryRevealStarted,
            "Game played fully."
        );
        
        games[senderOpponentHash].hashedAnswer = hashedAnswer;
        games[senderOpponentHash].expirationPlay = block.timestamp + 24 hours;
    }
    
    function requestPlay(address opponentAddress, bool answer) external payable {
        address senderAddress = msg.sender;
        bytes32 opponentSenderHash = sha256(abi.encodePacked(opponentAddress, senderAddress));
        
        require(
            msg.value == 1 ether,
            "Send 1 ETH to play."
        );
        
        require(
            block.timestamp < games[opponentSenderHash].expirationPlay,
            "Time limit for joining the game exceeded."
        );
        
        emit DepositForGame(senderAddress, opponentAddress);
        
        playGame(opponentAddress, senderAddress, answer);
    }
    
    function playGame(address opponentAddress, address senderAddress, bool answer) internal {
        bytes32 opponentSenderHash = sha256(abi.encodePacked(opponentAddress, senderAddress));
        
        require(
            games[opponentSenderHash].hashedAnswer != "",
            "Game not created yet."
        );
        
        games[opponentSenderHash].answerB = answer;
        games[opponentSenderHash].expiryRevealStarted = true;
        games[opponentSenderHash].expirationReveal = block.timestamp + 1 seconds;
    }
    
    function revealGame(address opponentAddress, bool answer, bytes32 secretKey) external {
        address senderAddress = msg.sender;
        bytes32 senderOpponentHash = sha256(abi.encodePacked(senderAddress, opponentAddress));
        bytes32 hashedAnswer = sha256(abi.encodePacked(answer, secretKey));
        
        verifyRevealAllowed(senderOpponentHash, hashedAnswer);
        
        games[senderOpponentHash].answerA = answer;
        handlePayoff(senderOpponentHash, senderAddress, opponentAddress);
    }
    
    function verifyRevealAllowed(bytes32 senderOpponentHash, bytes32 hashedAnswer) internal view {
        require(
            games[senderOpponentHash].expiryRevealStarted,
            "Game not played fully yet."
        );
        
        require(
            games[senderOpponentHash].hashedAnswer == hashedAnswer,
            "Hashes not coinciding."
        );
        
        require(
            block.timestamp < games[senderOpponentHash].expirationReveal,
            "Time limit for the answer reveal exceeded."
        );
    }
    
    function handlePayoff(bytes32 senderOpponentHash, address senderAddress, address opponentAddress) internal {
        address winnerAddress = calculateWinner(senderOpponentHash, senderAddress, opponentAddress);
        
        emit Winner(winnerAddress);
        
        deleteGame(senderOpponentHash);
        payoffsByAddress[winnerAddress] += 2 ether;
    }
    
    function calculateWinner(bytes32 opponentSenderHash, address senderAddress, address opponentAddress) internal view returns (address) {
        Game memory game = games[opponentSenderHash];
        
        if (game.answerA == game.answerB) {
            return senderAddress;
        } 
        
        else {
            return opponentAddress;
        }
    }
    
    function deleteGame(bytes32 opponentSenderHash) internal {
        delete(games[opponentSenderHash]);
    }

    function withdrawPayoff() external {
        uint256 payoffForAddress = payoffsByAddress[msg.sender];
 
        require(
            payoffForAddress > 0,
            "No payoff for this address available."
        );
        
        payoffsByAddress[msg.sender] = 0;
        payable(msg.sender).transfer(payoffForAddress);

        emit Payoff(msg.sender);
    }
    
    function claimExpirationPayoff(address opponentAddress) external {
        address senderAddress = msg.sender;
        bytes32 opponentSenderHash = sha256(abi.encodePacked(opponentAddress, senderAddress));
        
        require(
            games[opponentSenderHash].expiryRevealStarted,
            "Expiry not started yet."
        );
        
        require(
            block.timestamp >= games[opponentSenderHash].expirationReveal,
            "Time limit for the answer reveal not exceeded yet."
        );
        
        deleteGame(opponentSenderHash);
        payoffsByAddress[msg.sender] += 2 ether;
    }
    
    function cancelGame(address opponentAddress) external {
        address senderAddress = msg.sender;
        bytes32 senderOpponentHash = sha256(abi.encodePacked(senderAddress, opponentAddress));
        
        verifyCancelAllowed(senderOpponentHash);
        
        deleteGame(senderOpponentHash);
        payoffsByAddress[senderAddress] += 1 ether;
    }
    
    function verifyCancelAllowed(bytes32 senderOpponentHash) internal view {
        
        require(
            block.timestamp >= games[senderOpponentHash].expirationPlay,
            "Time limit for joining the game not exceeded yet."
        );
        
        require(
            !games[senderOpponentHash].expiryRevealStarted,
            "Game played fully."
        );
        
        require(
            games[senderOpponentHash].hashedAnswer != "",
            "Game not created yet."
        );
    }
    
}
