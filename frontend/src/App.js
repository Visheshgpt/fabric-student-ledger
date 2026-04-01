import { useState, useEffect } from 'react';
import RegisterStudent from './components/RegisterStudent';
import AddActivity from './components/AddActivity';
import ViewStudent from './components/ViewStudent';
import DepartmentStudents from './components/DepartmentStudents';
import { getUsers, setActiveUser, getActiveUser } from './services/api';

const tabs = [
  { id: 'register', label: 'Register Student' },
  { id: 'activity', label: 'Add Activity' },
  { id: 'view', label: 'View Student' },
  { id: 'department', label: 'By Department' },
];

function App() {
  const [activeTab, setActiveTab] = useState('register');
  const [users, setUsers] = useState([]);
  const [currentUser, setCurrentUser] = useState(getActiveUser());

  useEffect(() => {
    getUsers()
      .then((res) => setUsers(res.data))
      .catch(() => {
        // Fallback if backend is not running
        setUsers([
          { username: 'admin1', role: 'admin', department: '', org: 'UniversityOrg' },
          { username: 'registrar1', role: 'registrar', department: '', org: 'UniversityOrg' },
          { username: 'cs-staff1', role: 'staff', department: 'CS', org: 'DepartmentOrg' },
          { username: 'ee-staff1', role: 'staff', department: 'EE', org: 'DepartmentOrg' },
          { username: 'finance1', role: 'staff', department: 'finance', org: 'DepartmentOrg' },
          { username: 'library1', role: 'staff', department: 'library', org: 'DepartmentOrg' },
        ]);
      });
  }, []);

  const handleUserChange = (e) => {
    const username = e.target.value;
    setCurrentUser(username);
    setActiveUser(username);
  };

  const selectedUser = users.find((u) => u.username === currentUser);

  return (
    <div>
      <div className="header">
        <h1>Student Activity Ledger</h1>
        <p>Hyperledger Fabric · University Network</p>
      </div>

      <div className="user-bar">
        <div className="user-bar-left">
          <label className="user-label">Acting as:</label>
          <select className="user-select" value={currentUser} onChange={handleUserChange}>
            {users.map((u) => (
              <option key={u.username} value={u.username}>
                {u.username} ({u.role}{u.department ? `, ${u.department}` : ''})
              </option>
            ))}
          </select>
        </div>
        {selectedUser && (
          <div className="user-info">
            <span className={`role-badge role-${selectedUser.role}`}>{selectedUser.role}</span>
            {selectedUser.department && (
              <span className="dept-badge">{selectedUser.department}</span>
            )}
            <span className="org-badge">{selectedUser.org}</span>
          </div>
        )}
      </div>

      <div className="tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={`tab-btn ${activeTab === tab.id ? 'active' : ''}`}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="main-container">
        {activeTab === 'register' && <RegisterStudent />}
        {activeTab === 'activity' && <AddActivity />}
        {activeTab === 'view' && <ViewStudent />}
        {activeTab === 'department' && <DepartmentStudents />}
      </div>
    </div>
  );
}

export default App;
