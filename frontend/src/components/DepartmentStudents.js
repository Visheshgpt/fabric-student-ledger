import { useState } from 'react';
import { getStudentsByDepartment } from '../services/api';

const departments = ['CS', 'EE', 'ME', 'CE'];

export default function DepartmentStudents() {
  const [dept, setDept] = useState('CS');
  const [students, setStudents] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleQuery = async () => {
    setError('');
    setStudents(null);
    setLoading(true);
    try {
      const res = await getStudentsByDepartment(dept);
      setStudents(res.data);
    } catch (err) {
      setError(err.response?.data?.error || 'Error fetching students');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card">
      <div className="card-title">
        <span className="icon icon-orange">◈</span>
        Students by Department
      </div>

      <div className="search-row">
        <select
          className="form-select"
          value={dept}
          onChange={(e) => setDept(e.target.value)}
        >
          {departments.map((d) => (
            <option key={d} value={d}>{d}</option>
          ))}
        </select>
        <button className="btn btn-primary" onClick={handleQuery} disabled={loading} style={{ width: 'auto' }}>
          {loading ? <span className="loading" /> : 'Search'}
        </button>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {students && (
        <div className="student-info">
          <div className="divider" />
          <div className="activities-header">
            Found {students.length} student(s)
          </div>
          {students.length > 0 ? (
            students.map((s) => (
              <div className="activity-row" key={s.id}>
                <span className="activity-badge badge-exam">{s.department}</span>
                <span className="activity-details">
                  <strong>{s.id}</strong> — {s.name}
                </span>
                <span className="activity-time">{s.activities?.length || 0} activities</span>
              </div>
            ))
          ) : (
            <div className="empty-state">No students found in {dept} department.</div>
          )}
        </div>
      )}
    </div>
  );
}
