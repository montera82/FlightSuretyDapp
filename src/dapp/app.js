App = {
    web3Provider: null,
    contracts: {},
    metamaskAccountID: "0x0000000000000000000000000000000000000000",
    ownerID: "0x0000000000000000000000000000000000000000",

    init: async function () {
        /// Setup access to blockchain
        return await App.initWeb3();
    },

    initWeb3: async function () {
        /// Find or Inject Web3 Provider
        /// Modern dapp browsers...
        if (window.ethereum) {
            App.web3Provider = window.ethereum;
            try {
                // Request account access
                await window.ethereum.enable();
            } catch (error) {
                // User denied account access...
                console.error("User denied account access")
            }

        }
        // Legacy dapp browsers...
        else if (window.web3) {
            App.web3Provider = window.web3.currentProvider;

        }
        // If no injected web3 instance is detected, fall back to Ganache
        else {
            App.web3Provider = new Web3.providers.HttpProvider('http://localhost:7545');

        }
        App.getMetaskAccountID();
        return await App.initContract();
        //return await App.getOwnerID();
    },

    getMetaskAccountID: function () {
        web3 = new Web3(App.web3Provider);

        // Retrieving accounts
        web3.eth.getAccounts(function (err, res) {
            if (err) {
                console.log('Error:', err);
                return;
            }
            App.metamaskAccountID = res[0];
        })
    },
    getOwnerID: async function () {

        const deployed = await App.contracts.FlightSuretyApp.deployed();
        App.ownerID = await deployed.getContractOwner();

        return App.ownerID;
    },

    initContract: async function () {
        /// Source the truffle compiled smart contracts
        var flightSuretyApp = '../../build/contracts/FlightSuretyApp.json';

        /// JSONfy the smart contracts
        $.getJSON(flightSuretyApp, function (data) {
            // console.log('data', data);
            var contractArtifact = data;
            App.contracts.FlightSuretyApp = TruffleContract(contractArtifact);
            App.contracts.FlightSuretyApp.setProvider(App.web3Provider);

            App.fetchEvents();
        });

        return App.bindEvents();
    },

    bindEvents: function () {
        $(document).on('click', App.handleButtonClick);

    },

    handleButtonClick: async function (event) {
        var processId = parseInt($(event.target).data('id'));

        App.getMetaskAccountID();
        console.log('processId', processId);

        switch (processId) {
            case 1:
                return await App.registerSelectedMetamaskAccount(event);
                break;
            case 2:
                return await App.registerInputedAccount(event);
                break;
            case 3:
                await App.fundSelectedAirline(event);
                return await App.getContractBalance();
                break;
            case 4:
                await App.buyInsurance(event);
                return await App.getContractBalance();
                break;
            case 5:
                await App.fetchFlightStatus(event);
                return await App.getContractBalance();
                break;
            case 6:
                return await App.getContractBalance();
                break;
            case 7:
                await App.getInsuranceClaim();
                return await App.getContractBalance();
                break;
            case 8:
                await App.payInsuranceClaim();
                return await App.getContractBalance();
                break;
        }
    },

    registerSelectedMetamaskAccount: async function (event) {
        const ownerID = await App.getOwnerID();
        event.preventDefault();
        console.log(App.ownerID, App.metamaskAccountID);

        const contract = await App.contracts.FlightSuretyApp.deployed();
        try {
            await contract.registerAirline(App.metamaskAccountID, { from: ownerID });
            console.log('registerAirline');
        } catch (err) {
            console.log(err.message);
        }

    },

    registerInputedAccount: async function (event) {
        const ownerID = await App.getOwnerID();
        event.preventDefault();
        console.log(App.ownerID, App.metamaskAccountID);

        const inputedAirline = $('#airline-address').val();
        if (inputedAirline === '') {
            alert('Provide Airline Address');
            return;
        }

        const contract = await App.contracts.FlightSuretyApp.deployed();
        try {
            await contract.registerAirline(inputedAirline, { from: ownerID });
            console.log('registerAirline');
        } catch (err) {
            console.log(err.message);
        }

    },

    fundSelectedAirline: async function (event) {
        event.preventDefault();

        const fundAmount = $('#fund-amount').val();
        if (fundAmount === '') {
            alert('Provide fund amount');
            return;
        }

        const contract = await App.contracts.FlightSuretyApp.deployed();
        try {
            await contract.fund({ from: App.metamaskAccountID, value: web3.toWei(fundAmount, "ether") });
            console.log('fund');
        } catch (err) {
            console.log(err.message);
        }
    },

    buyInsurance: async function (event) {
        event.preventDefault();

        const flightTimestamp = $('#flights').val();
        const flightNumber = $('#flights option:selected').text();


        console.log({ flightNumber });
        if (flightTimestamp == '-1') {
            alert('Select flight');
            return;
        }

        const insuranceAmount = $('#insurance-amount').val();
        if (insuranceAmount === '') {
            alert('Provide insurance amount');
            return;
        }

        const contract = await App.contracts.FlightSuretyApp.deployed();
        try {
            await contract.buy(flightNumber, flightTimestamp, { from: App.metamaskAccountID, value: web3.toWei(insuranceAmount, "ether") });
            console.log('buy insurance');
        } catch (err) {
            console.log(err.message);
        }
    },

    fetchFlightStatus: async function (event) {
        event.preventDefault();
        const flightNumber = $('#oracles-flights option:selected').text();
        const flightTimestamp = $('#oracles-flights').val();
        if (flightTimestamp == '-1') {
            alert('Select Flight');
            return;
        }

        const contract = await App.contracts.FlightSuretyApp.deployed();
        try {
            await contract.
                fetchFlightStatus(App.metamaskAccountID, flightNumber, flightTimestamp, { from: App.metamaskAccountID });
            $('#display-wrapper').append(`<p id='info'>Getting flight status for Airline: ${App.metamaskAccountID}</p>`);
            $('#info').delay(600).fadeOut(3600);
        } catch (error) {
            console.log(error);
        }
    },

    getContractBalance: async function () {
        const contract = await App.contracts.FlightSuretyApp.deployed();
        const balance = await contract.getDataContractBalance();

        $('#contract-bal').text(web3.fromWei(balance, "ether"));
    },

    getInsuranceClaim: async function () {
        const contract = await App.contracts.FlightSuretyApp.deployed();
        const claim = await contract.getInsuranceClaim({from: App.metamaskAccountID});

        $('#insurance-claim').val(web3.fromWei(claim, "ether"));
    },
    payInsuranceClaim: async function () {
        const contract = await App.contracts.FlightSuretyApp.deployed();

        const amount = $('#insurance-claim').val();
        await contract.pay({ from: App.metamaskAccountID});
    },

    fetchEvents: function () {
        if (typeof App.contracts.FlightSuretyApp.currentProvider.sendAsync !== "function") {
            App.contracts.FlightSuretyApp.currentProvider.sendAsync = function () {
                return App.contracts.FlightSuretyApp.currentProvider.send.apply(
                    App.contracts.FlightSuretyApp.currentProvider,
                    arguments
                );
            };
        }

        App.contracts.FlightSuretyApp.deployed().then(function (instance) {
            var events = instance.allEvents(function (err, log) {
                if (!err)
                    $("#ftc-events").append('<li>' + log.event + ' - ' + log.transactionHash + '</li>');
            });
        }).catch(function (err) {
            console.log(err.message);
        });

    },
};

$(function () {
    $(window).load(function () {
        App.init();
    });
});

// monitor metamask account change
window.ethereum.on('accountsChanged', function (accounts) {
    console.log('metamask changed!', accounts[0]);
    App.metamaskAccountID = accounts[0];
})