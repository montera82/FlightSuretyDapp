import Web3 from 'web3';

export default class Oracle {

    flightSuretyApp = {};
    address = '0x00000000000000000000000000';
    ORACLE_REGISTRATION_FEE = "1";
    web3;
    indexes;
    STATUS_CODES = [0, 10, 20, 30, 40, 50];

    constructor(config, address, FlightSuretyAppAbi, FlightSuretyAppAddress) {
        let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
        this.flightSuretyApp = new web3.eth.Contract(FlightSuretyAppAbi, FlightSuretyAppAddress);
        this.address = address;
        this.web3 = web3;
    }

    /**
     * Register oracle and return unique indices
     * @returns 
     */
    async register() {
        // const bal = await this.web3.eth.getBalance(this.address)
        // console.log("XXXXXX", bal);

        await this.flightSuretyApp.methods.registerOracle().send(
            { from: this.address, value: this.web3.utils.toWei(this.ORACLE_REGISTRATION_FEE, "ether"), gas: 3000000 } // why must i pass gas??? would using truffle-contract resolve this ? 
        );
        this.indexes = await this.flightSuretyApp.methods.getMyIndexes().call({ from: this.address });

        //console.log("XXXXXX", contract);
        return this.indexes;
    }

    async submitOracleResponse(
        index,
        airline,
        flight,
        timestamp
    ) {
        const randomIndex = Math.floor(Math.random() * this.STATUS_CODES.length);
        //const statusCode = 20;
        const statusCode = this.STATUS_CODES[randomIndex]
        console.log({statusCode});
        try {
            await this.flightSuretyApp.methods.submitOracleResponse(
                index,
                airline,
                flight,
                timestamp,
                statusCode
            ).send({ from: this.address, gas: 500000, gasPrice: 20000000})
        } catch (error) {
            console.log(error);
        }
        
    }
}