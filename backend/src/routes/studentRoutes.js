const express = require('express');
const router = express.Router();
const {
  registerStudent,
  addActivity,
  getStudent,
  getStudentsByDepartment,
  getStudentHistory,
} = require('../controllers/studentController');

router.post('/register', registerStudent);
router.post('/activity', addActivity);
router.get('/department/:dept', getStudentsByDepartment);
router.get('/:id/history', getStudentHistory);
router.get('/:id', getStudent);

module.exports = router;
