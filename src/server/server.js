import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import Oracle from './models/oracle';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
let accounts;
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
const oracles = [];

// instantiate oracles
(async function () {

  accounts = await web3.eth.getAccounts();
  web3.eth.defaultAccount = accounts[0];

  for (let i = 3; i < 100; i++) {
    let _oracle = new Oracle(config, accounts[i], FlightSuretyApp.abi, config.appAddress);
    let indices = await _oracle.register();
    console.log(`ORACLE INDEX ${i}`, indices, ' listening..');
    oracles.push(
      _oracle
    )
  }
})()


flightSuretyApp.events.OracleRequest({
  fromBlock: 0
}, function (error, event) {
  // if (error) console.log(error)

  const { index, airline, flight, timestamp } = event.returnValues;

  const matchedOracles = oracles.filter((oracle) => {
    return oracle.indexes.includes(index);
  });

  console.log(`${matchedOracles.length} oracles found for this request : Index: ${index}`);
  matchedOracles.map((oracle) => {
    oracle.submitOracleResponse(index, airline, flight, timestamp);
  })

  //console.log('Processed all ')
   console.log({index, airline, flight, timestamp });
});



flightSuretyApp.events.FlightStatusInfo({
  fromBlock: 0
}, function (error, event) {
  //if (error) console.log(error)
});

const app = express();
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!'
  })
})

export default app;


