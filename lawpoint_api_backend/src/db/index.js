const pool = require('../postgres');

function toPgPlaceholders(sql) {
  let i = 0;
  return sql.replace(/\?/g, () => `$${++i}`);
}

async function run(sql, params = []) {
  const pgSql = toPgPlaceholders(sql);
  const result = await pool.query(pgSql, params);
  return {
    rowCount: result.rowCount,
    rows: result.rows,
  };
}

async function get(sql, params = []) {
  const pgSql = toPgPlaceholders(sql);
  const result = await pool.query(pgSql, params);
  return result.rows[0] || null;
}

async function all(sql, params = []) {
  const pgSql = toPgPlaceholders(sql);
  const result = await pool.query(pgSql, params);
  return result.rows;
}

module.exports = {
  pool,
  run,
  get,
  all,
};