const { getContract } = require('../fabric/connection');

/**
 * Extract the active username from the X-User header.
 * Defaults to 'admin1' if not provided.
 */
function getUser(req) {
  return req.headers['x-user'] || 'admin1';
}

// POST /api/students/register
async function registerStudent(req, res) {
  const { id, name, department } = req.body;
  if (!id || !name || !department) {
    return res.status(400).json({ error: 'id, name, and department are required' });
  }

  let gateway;
  try {
    const conn = await getContract(getUser(req));
    gateway = conn.gateway;
    await conn.contract.submitTransaction('RegisterStudent', id, name, department);
    res.json({ message: `Student ${id} registered successfully` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    if (gateway) gateway.disconnect();
  }
}

// POST /api/students/activity
async function addActivity(req, res) {
  const { id, type, details } = req.body;
  if (!id || !type || !details) {
    return res.status(400).json({ error: 'id, type, and details are required' });
  }

  let gateway;
  try {
    const conn = await getContract(getUser(req));
    gateway = conn.gateway;
    await conn.contract.submitTransaction('AddActivity', id, type, details);
    res.json({ message: `Activity added for student ${id}` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    if (gateway) gateway.disconnect();
  }
}

// GET /api/students/:id
async function getStudent(req, res) {
  const { id } = req.params;
  let gateway;
  try {
    const conn = await getContract(getUser(req));
    gateway = conn.gateway;
    const result = await conn.contract.evaluateTransaction('GetStudent', id);
    res.json(JSON.parse(result.toString()));
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    if (gateway) gateway.disconnect();
  }
}

// GET /api/students/department/:dept
async function getStudentsByDepartment(req, res) {
  const { dept } = req.params;
  let gateway;
  try {
    const conn = await getContract(getUser(req));
    gateway = conn.gateway;
    const result = await conn.contract.evaluateTransaction('GetStudentsByDepartment', dept);
    res.json(JSON.parse(result.toString()));
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    if (gateway) gateway.disconnect();
  }
}

// GET /api/students/:id/history
async function getStudentHistory(req, res) {
  const { id } = req.params;
  let gateway;
  try {
    const conn = await getContract(getUser(req));
    gateway = conn.gateway;
    const result = await conn.contract.evaluateTransaction('GetStudentHistory', id);
    res.json(JSON.parse(result.toString()));
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    if (gateway) gateway.disconnect();
  }
}

module.exports = { registerStudent, addActivity, getStudent, getStudentsByDepartment, getStudentHistory };
