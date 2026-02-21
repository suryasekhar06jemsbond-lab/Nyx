const { Pool } = require('pg');

class Database {
    constructor(url) {
        this.pool = new Pool({
            connectionString: url,
        });
    }

    async execute(query, params) {
        const client = await this.pool.connect();
        try {
            const result = await client.query(query, params);
            return {
                rows: result.rows,
                affected_rows: result.rowCount,
            };
        } finally {
            client.release();
        }
    }

    async close() {
        await this.pool.end();
    }
}

module.exports = {
    Database,
};
