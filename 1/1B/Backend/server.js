const express = require('express');
const sql = require('mssql/msnodesqlv8');
const app = express();
const port = 3000;

// SQL Server connection configuration
const config = {
    connectionString : 'Server=localhost;Database=test1;Trusted_Connection=Yes;Driver={SQL Server};'
};

const cors = require('cors');
app.use(cors());

// Serve static files (for HTML)
app.use(express.static('.'));

// Endpoint to call the stored procedure
app.get('/api/GetAgentStateIntervals', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        console.log('✅ Connected to DB');

        const result = await pool.request()
            .input('agentId', sql.BigInt, req.query.agentId)
            .input('domainId', sql.BigInt, req.query.domainId)
            .input('startDate', sql.DateTime2, req.query.startDate)
            .input('endDate', sql.DateTime2, req.query.endDate)
            .input('state', sql.NVarChar, req.query.state)
            .input('pageNumber', sql.Int, req.query.pageNumber)
            .input('pageSize', sql.Int, req.query.pageSize)
            .input('sortColumn', sql.NVarChar, req.query.sortColumn)
            .input('sortDirection', sql.NVarChar, req.query.sortDirection)
            .execute('GetAgentStateIntervals');

        console.log('✅ Procedure executed, result:');
        console.dir(result, { depth: null });
        res.json(result.recordset);

        await pool.close();
    } catch (error) {
        console.error('❌ Connection/query failed:');
        console.dir(error, { depth: null });
        res.status(500).send('Database connection/query execution failed');
    }

    return res;
});


app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});