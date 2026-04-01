import { useState } from 'react';
import { getStudent, getStudentHistory } from '../services/api';

const badgeClass = { fee: 'badge-fee', library: 'badge-library', exam: 'badge-exam' };

export default function ViewStudent() {
  const [studentId, setStudentId] = useState('');
  const [student, setStudent] = useState(null);
  const [history, setHistory] = useState(null);
  const [error, setError] = useState('');
  const [view, setView] = useState('info');
  const [loading, setLoading] = useState(false);

  const handleGetStudent = async () => {
    if (!studentId.trim()) return;
    setError('');
    setStudent(null);
    setHistory(null);
    setLoading(true);
    try {
      const res = await getStudent(studentId);
      setStudent(res.data);
      setView('info');
    } catch (err) {
      setError(err.response?.data?.error || 'Student not found');
    } finally {
      setLoading(false);
    }
  };

  const handleGetHistory = async () => {
    if (!studentId.trim()) return;
    setError('');
    setHistory(null);
    setLoading(true);
    try {
      const res = await getStudentHistory(studentId);
      setHistory(res.data);
      setView('history');
    } catch (err) {
      setError(err.response?.data?.error || 'Error fetching history');
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (ts) => {
    try {
      return new Date(ts).toLocaleString();
    } catch {
      return ts;
    }
  };

  return (
    <div className="card">
      <div className="card-title">
        <span className="icon icon-purple">?</span>
        View Student
      </div>

      <div className="search-row">
        <input
          className="form-input"
          placeholder="Enter Student ID..."
          value={studentId}
          onChange={(e) => setStudentId(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleGetStudent()}
        />
        <button className={`btn btn-secondary ${view === 'info' && student ? 'active' : ''}`} onClick={handleGetStudent}>
          {loading && view === 'info' ? <span className="loading" /> : 'Info'}
        </button>
        <button className={`btn btn-secondary ${view === 'history' && history ? 'active' : ''}`} onClick={handleGetHistory}>
          {loading && view === 'history' ? <span className="loading" /> : 'History'}
        </button>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {student && view === 'info' && (
        <div className="student-info">
          <div className="divider" />
          <div className="info-grid">
            <div className="info-item">
              <div className="label">ID</div>
              <div className="value">{student.id}</div>
            </div>
            <div className="info-item">
              <div className="label">Name</div>
              <div className="value">{student.name}</div>
            </div>
            <div className="info-item">
              <div className="label">Department</div>
              <div className="value">{student.department}</div>
            </div>
          </div>

          <div className="activities-header">
            Activities ({student.activities?.length || 0})
          </div>

          {student.activities?.length > 0 ? (
            student.activities.map((a, i) => (
              <div className="activity-row" key={i}>
                <span className={`activity-badge ${badgeClass[a.type] || ''}`}>{a.type}</span>
                <span className="activity-details">{a.details}</span>
                <span className="activity-time">{formatTime(a.timestamp)}</span>
              </div>
            ))
          ) : (
            <div className="empty-state">No activities recorded yet.</div>
          )}
        </div>
      )}

      {history && view === 'history' && (
        <div className="student-info">
          <div className="divider" />
          <div className="activities-header">
            Transaction History ({history.length})
          </div>
          {history.length > 0 ? (
            history.map((h, i) => (
              <div className="history-item" key={i}>
                <div className="tx-id">TX: {h.txId}</div>
                <div className="tx-meta">
                  <span>{formatTime(h.timestamp)}</span>
                  <span>{h.value?.activities?.length || 0} activities</span>
                </div>
              </div>
            ))
          ) : (
            <div className="empty-state">No transaction history found.</div>
          )}
        </div>
      )}
    </div>
  );
}
