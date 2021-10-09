
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        //await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) can register itself even without first providing funding', async () => {
        const { flightSuretyApp, flightSuretyData, firstAirline } = config;
        await flightSuretyApp.registerAirline(firstAirline, { from: firstAirline });

        const registerd = await flightSuretyData.isAirline.call(firstAirline);
        assert.equal(registerd, true, "Airline should be able to register itself even before providing funding");
    })

    // not sure of this requirement, an airline can not register another unless its funded, but can it register itself???
    it.skip('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
        const { flightSuretyApp, flightSuretyData, firstAirline } = config;
        const newAirline = accounts[2];

        await flightSuretyApp.registerAirline(newAirline, { from: firstAirline });

        const result = await flightSuretyData.isAirline.call(newAirline);
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");
    });

    it('Airline should be able to successfully provide funds after registration', async () => {
        let { firstAirline, flightSuretyApp, flightSuretyData } = config;
        await flightSuretyApp.fund({ from: firstAirline, value: web3.utils.toWei("10", "ether"), gasPrice: 0 });
        const hasFunded = await config.flightSuretyData.hasProvidedFunds.call(firstAirline);

        const bal = await web3.eth.getBalance(flightSuretyData.address);

        assert.equal(true, hasFunded, "A registered airline should be able to successfuly provide funding")
        assert.equal(10,web3.utils.fromWei(bal, "ether"), "Contracts balance should be 10 ether" );
    });

    it('(Passenger) should be able to buy insurance', async () => {
        //// accounts[8] to accounts[12]
        let {  flightSuretyApp, flightSuretyData } = config;
        const passenger1 = accounts[8];
        const flight = "FL01";
        const timestamp = new Date().getTime();
        const price = web3.utils.toWei("1", "ether");

        const balB4 = await web3.eth.getBalance(flightSuretyData.address);
        await flightSuretyApp.buy(flight, timestamp, { from: passenger1, value: price, gasPrice: 0 });
        const isInsured = await config.flightSuretyData.isInsured.call(passenger1);
        const balAfter = await web3.eth.getBalance(flightSuretyData.address);

        //console.log("balance in eth", web3.utils.fromWei(bal, "ether"))
        assert.equal(true, isInsured, "Passenger should be able to insure flight");
        assert.equal(Number(balB4)+Number(price),balAfter, "Contracts balance should have increased by price amount" );
    });

});
