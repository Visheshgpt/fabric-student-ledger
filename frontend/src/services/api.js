import axios from 'axios';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:3001';

const api = axios.create({ baseURL: API_BASE });

// Set the active user for all requests
let activeUser = 'admin1';

export function setActiveUser(username) {
  activeUser = username;
}

export function getActiveUser() {
  return activeUser;
}

// Attach X-User header to every request
api.interceptors.request.use((config) => {
  config.headers['X-User'] = activeUser;
  return config;
});

// Auth
export function getUsers() {
  return api.get('/api/auth/users');
}

// Students
export function registerStudent(id, name, department) {
  return api.post('/api/students/register', { id, name, department });
}

export function addActivity(id, type, details) {
  return api.post('/api/students/activity', { id, type, details });
}

export function getStudent(id) {
  return api.get(`/api/students/${id}`);
}

export function getStudentsByDepartment(dept) {
  return api.get(`/api/students/department/${dept}`);
}

export function getStudentHistory(id) {
  return api.get(`/api/students/${id}/history`);
}
