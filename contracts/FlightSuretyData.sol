pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    struct Airline {
        address airline;
        bool isFunded;
    }

    struct Passenger {
        address passenger;
        uint256 insurance;
    }
    // key = flight
    mapping(string => Passenger[]) flightPassengers;
    // key = passenger
    mapping(address => bool) private passengerInsured; // track passengers insurancd to avoid looping
    mapping(address => Airline) private airlines;
    // key=passenger value=claim demoninated in eth
    mapping(address => uint256) private insuranceClaims;

    uint256 private airlineCount = 0;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
    }

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
        require(operational, "Contract is currently not operational");
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
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *Notes
     * first airline can register others
     * existing airline can register others
     * if airline count >=4, use consensus of 50% vote to allow 5th airline and so on
     */
    function registerAirline(address _airline)
        external
        requireIsOperational
        returns (bool success)
    {
        airlines[_airline] = Airline(_airline, false);
        airlineCount++;
        return true;
    }

    /**
     * @dev Buy insurance for a flight
     *Notes;;
     * passengers may pay up to 1 ether max for flight
     * flight numbers and timestamps are fixed and can be defined in the dapp client
     * transfers money to contract account
     *
     */

    function buy(
        address _passenger,
        string _flight,
        uint256 _timeStamp,
        uint256 _amountPaid
    ) external payable requireIsOperational {
        flightPassengers[_flight].push(Passenger(_passenger, _amountPaid));
        // https://ethereum.stackexchange.com/a/27518/79328
        passengerInsured[_passenger] = true;
        //emit BoughtInsurance(_passenger, _amountPaid);
    }

    /**
     *  @dev Credits payouts to insurees
     * Notes : an amount is stored on behalf of customer address here
     * : using a storage var
     * if flight is delayed ( i.e code of 20 , we pay the passenger 1.5x what they invested )
     */
    function creditInsurees(string flight) external requireIsOperational {
        Passenger[] memory list = flightPassengers[flight];

        require(list.length > 0, "No passengers found for flight");
        
        //credit customers account on contract x 1.5
        for (uint256 i = 0; i < list.length; i++) {
            Passenger memory p = list[i];
            
            uint256 insurancePaid = p.insurance;
            insuranceClaims[p.passenger] = insuranceClaims[p.passenger].add(insurancePaid).add(insurancePaid.mul(1).div(2));
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *  Notes : customers call this to withdraw funds in the second step
     */
    function pay(address passenger, uint256 amount)
        external
        requireIsOperational
    {
        insuranceClaims[passenger] = 0;
        passenger.transfer(amount);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     * ==== Notes
     * airline must have passed registration step
     * airline pays 10th
     * airline can not paticipate in contract until it submits funding of 10eth
     */
    function fund(address _funder) public payable requireIsOperational {
        // require(isAirline(msg.sender), "Must be a registered airline first");
        //require(msg.value >= 10 ether, "Amount must be greater than 10eth");
        //address(this).transfer(msg.value); // TODO: would i need to do check-effects here?
        //_funder
        airlines[_funder].isFunded = true;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function isAirline(address _airline)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return airlines[_airline].airline == _airline;
    }

    function hasProvidedFunds(address _airline)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return airlines[_airline].isFunded;
    }

    function getAirlineCount()
        public
        view
        requireIsOperational
        returns (uint256)
    {
        return airlineCount;
    }

    // checks if sender bought insurance
    function isInsured(address passenger)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return passengerInsured[passenger];
    }

    function getInsuranceClaim(address passenger)
        public
        view
        requireIsOperational
        returns (uint256)
    {
        return insuranceClaims[passenger];
    }

    // function getFlights() external view returns (string[]) {
    //     return flights;
    // }
    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        //fund();
    }
}
