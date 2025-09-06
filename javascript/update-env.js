const fs = require('fs');
const path = require('path');

const runLatestPath = path.join(__dirname, '../broadcast/Deployments.s.sol/1/run-latest.json');
const envPath = path.join(__dirname, '../.env');

// Read and parse the run-latest.json file
fs.readFile(runLatestPath, 'utf8', (err, data) => {
  if (err) {
    console.error('Error reading run-latest.json:', err);
    return;
  }

  const runLatest = JSON.parse(data);
  const createTransactions = runLatest.transactions.filter(tx => tx.transactionType === 'CREATE');

  if (createTransactions.length === 0) {
    console.log('No "CREATE" transactions found in run-latest.json');
    return;
  }

  // Read the existing .env file
  fs.readFile(envPath, 'utf8', (err, envData) => {
    let envLines = [];
    if (!err) {
      envLines = envData.split('\n');
    }

    // Create a map of existing keys to their lines
    const envMap = new Map();
    envLines.forEach((line, index) => {
      const key = line.split('=')[0];
      if (key) {
        envMap.set(key, { line, index });
      }
    });

    // Update or add contract addresses
    createTransactions.forEach(tx => {
      const { contractName, contractAddress } = tx;
      if (contractName && contractAddress) {
        const key = contractName.toUpperCase() + '_ADDRESS';
        const newLine = `${key}=${contractAddress}`;
        if (envMap.has(key)) {
          const { index } = envMap.get(key);
          envLines[index] = newLine;
        } else {
          envLines.push(newLine);
        }
      }
    });

    // Write the updated content back to the .env file
    fs.writeFile(envPath, envLines.join('\n'), 'utf8', (err) => {
      if (err) {
        console.error('Error writing to .env file:', err);
        return;
      }
      console.log('Successfully updated .env file with contract addresses.');
    });
  });
});