pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    _FlightSuretyData flightSuretyData;
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20; // flight is delayed due to airline, payment process should get triggered here
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    address[] private multicalls = new address[](0);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        // Modify to call data contract's status
        require(isOperational(), "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     * Notes, do i need to pass the data contract address here?
     */
    constructor(address dataContractAddress) public {
        contractOwner = msg.sender;
        flightSuretyData = _FlightSuretyData(dataContractAddress);

        // register first airline on deploy
        flightSuretyData.registerAirline(msg.sender);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     
     */
    event registered(uint256 debug);

    function registerAirline(address _airline)
        external
        requireIsOperational
        returns (bool success)
    {
        uint256 airlinesCount = flightSuretyData.getAirlineCount();
        flightSuretyData.registerAirline(_airline);

        if (airlinesCount >= 4) {
            bool isDuplicate = false;
            for (uint256 i = 0; i < multicalls.length; i++) {
                if (multicalls[i] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }

            require(
                !isDuplicate,
                "Caller already voted for this airline registration"
            );

            multicalls.push(msg.sender);

            // check if 50% of existing airlines have voted, then add the guy
            if (multicalls.length >= airlinesCount / 2) {
                flightSuretyData.registerAirline(_airline);

                multicalls = new address[](0);
            }
        } else {
            flightSuretyData.registerAirline(_airline);
        }

        return true;
    }

    function fund() public payable requireIsOperational {
        require(
            flightSuretyData.isAirline(msg.sender),
            "Must first be registered before providing funds"
        );
        require(msg.value >= 10 ether, "Must provide atleast 10 ether");
        address(uint160(address(flightSuretyData))).transfer(msg.value);

        // //return change : was throwing a vm error, cycle back to this, need debug testing
        // if (msg.value > 10 ether) {
        //     msg.sender.transfer(msg.value - 10 ether);
        // }

        flightSuretyData.fund(msg.sender);
    }

    /**
     * @dev Register a future flight for insuring.
     ** Notes : may be hardcode all flights user can choose in the UI
     */
    function registerFlight() external pure {}

    /**
     * @dev Called after oracle has updated flight status
     * Notes: Triggered When the Oracle comes back with a result,
     * If flight was on time, i.e statusCode that is not 20,
     *this function determines what happens next etc,
     * in most cases you only want to react for 20, and then look for
     *  percengers that purchased this flight andn look
     * for how much they should be creadited
     */

    //  struct Insurance {
    //     address passenger;
    //     string flight;
    //     uint256 timestamp;
    //     uint256 amountPaid;
    //     bool isInsured;
    // }

    // mapping(address => Insurance) private insurances;

    // address = flight, passengers = Struct{ passenger, amountPaid}
    // mapping(address => passengers[]) flightPassengers;

    // struct Passenger {
    //     address passenger;
    //     amountPaid uint;
    // }
    // mapping(address => Passenger[]) flightPassengers;

    function processFlightStatus(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal requireIsOperational {
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key].isOpen = false;
        flightSuretyData.creditInsurees(flight);
    }

    // Generate a request for oracles to fetch flight information
    // Notes: user would click a button on UI, and it'll call this
    // function, which then pushes and event that would then be picked
    // up by the oracles and then respond to them
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    ) external requireIsOperational {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    function buy(string _flight, uint256 _timestamp)
        external
        payable
        requireIsOperational
    {
        require(
            msg.value <= 1 ether,
            "Max amount allowed for insurance purchase exceeded."
        );

        address(uint160(address(flightSuretyData))).transfer(msg.value);

        // persist data
        flightSuretyData.buy(msg.sender, _flight, _timestamp, msg.value);
        //revert();
    }

    function getContractOwner()
        public
        view
        requireIsOperational
        returns (address)
    {
        return contractOwner;
    }

    // get contract balance for display on FE
    function getDataContractBalance()
        public
        view
        requireIsOperational
        returns (uint256)
    {
        return address(flightSuretyData).balance;
    }

    function getInsuranceClaim()
        public
        view
        requireIsOperational
        returns (uint256)
    {
        return flightSuretyData.getInsuranceClaim(msg.sender);
    }

    function pay() public requireIsOperational {
        uint256 claim = flightSuretyData.getInsuranceClaim(msg.sender);
        require(claim > 0, "No insurance amount accrued");
        require(msg.value <= claim, "Invalid claim amount");
        flightSuretyData.pay(msg.sender, claim);
    }

    // region ORACLE MANAGEMENT
    /* #region Main */
    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable requireIsOperational {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes()
        external
        view
        requireIsOperational
        returns (uint8[3])
    {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external requireIsOperational {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            if (statusCode == 20 ) {
                processFlightStatus(index, airline, flight, timestamp, statusCode);
            }
        }
    }

    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }
    /* #endregion */
    // endregion
}

contract _FlightSuretyData {
    function registerAirline(address _airline) external returns (bool success);

    function fund(address funder) public payable;

    function isAirline(address _airline) public view returns (bool);

    function getAirlineCount() public view returns (uint256);

    function buy(
        address _passenger,
        string _flight,
        uint256 _timeStamp,
        uint256 _amountPaid
    ) external payable;

    function creditInsurees(string flight) external;

    function pay(address passenger, uint256 amount) external;

    function getInsuranceClaim(address passenger) public view returns (uint256);

    function isOperational() public view returns (bool);
}
