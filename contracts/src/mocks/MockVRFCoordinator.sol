// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockVRFCoordinator
/// @notice Simulates Chainlink VRF v2.5 coordinator for local testing.
/// @dev Returns deterministic "random" values based on request parameters.
///      Immediately calls back the consumer's fulfillRandomWords.
contract MockVRFCoordinator {
    uint256 private _requestCounter;
    uint256 private _seed;

    struct Request {
        address consumer;
        uint256 numWords;
        uint256 requestId;
        bool fulfilled;
    }

    mapping(uint256 => Request) public requests;

    event RandomWordsRequested(
        uint256 indexed requestId,
        address indexed consumer,
        uint256 numWords
    );
    event RandomWordsFulfilled(
        uint256 indexed requestId,
        address indexed consumer,
        uint256[] randomWords
    );

    constructor(uint256 initialSeed) {
        _seed = initialSeed;
    }

    /// @notice Request random words (simulated).
    /// @param numWords Number of random words to generate.
    /// @return requestId The unique request identifier.
    function requestRandomWords(
        bytes32, // keyHash (ignored in mock)
        uint256, // subId (ignored in mock)
        uint16,  // requestConfirmations (ignored in mock)
        uint32,  // callbackGasLimit (ignored in mock)
        uint32 numWords
    ) external returns (uint256 requestId) {
        _requestCounter++;
        requestId = _requestCounter;

        requests[requestId] = Request({
            consumer: msg.sender,
            numWords: numWords,
            requestId: requestId,
            fulfilled: false
        });

        emit RandomWordsRequested(requestId, msg.sender, numWords);
        return requestId;
    }

    /// @notice Fulfill the random words request (call from test/demo script).
    /// @dev Generates deterministic pseudo-random values.
    /// @param requestId The request to fulfill.
    function fulfillRandomWords(uint256 requestId) external {
        Request storage req = requests[requestId];
        require(req.consumer != address(0), "Request not found");
        require(!req.fulfilled, "Already fulfilled");

        uint256[] memory randomWords = new uint256[](req.numWords);
        for (uint256 i = 0; i < req.numWords; i++) {
            _seed = uint256(keccak256(abi.encodePacked(_seed, requestId, i, block.timestamp)));
            randomWords[i] = _seed;
        }

        req.fulfilled = true;

        // Call back the consumer
        (bool success,) = req.consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );
        require(success, "Callback failed");

        emit RandomWordsFulfilled(requestId, req.consumer, randomWords);
    }

    /// @notice Fulfill with specific random words (for scripted demo).
    /// @param requestId The request to fulfill.
    /// @param randomWords The specific random values to use.
    function fulfillRandomWordsWithValues(uint256 requestId, uint256[] calldata randomWords) external {
        Request storage req = requests[requestId];
        require(req.consumer != address(0), "Request not found");
        require(!req.fulfilled, "Already fulfilled");
        require(randomWords.length == req.numWords, "Wrong word count");

        req.fulfilled = true;

        (bool success,) = req.consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );
        require(success, "Callback failed");

        emit RandomWordsFulfilled(requestId, req.consumer, randomWords);
    }

    /// @notice Update the seed for new randomness.
    function setSeed(uint256 newSeed) external {
        _seed = newSeed;
    }
}
