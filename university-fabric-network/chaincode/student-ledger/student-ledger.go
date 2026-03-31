package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-chaincode-go/pkg/cid"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing the University Student Activity Ledger
type SmartContract struct {
	contractapi.Contract
}

// ─────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────

// Activity represents a single student activity record
type Activity struct {
	Type       string `json:"type"` // "fee" | "library" | "exam"
	Details    string `json:"details"`
	Timestamp  string `json:"timestamp"`
	RecordedBy string `json:"recordedBy"` // MSP ID of the recording org
	StaffDept  string `json:"staffDept"`  // department attribute of the staff who recorded it
}

// Student is the main ledger asset
type Student struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	Department string     `json:"department"` // "CS" | "EE" | "ME" | "CE"
	Activities []Activity `json:"activities"`
	CreatedAt  string     `json:"createdAt"`
}

// ─────────────────────────────────────────────
// Valid Enums
// ─────────────────────────────────────────────

var validDepartments = map[string]bool{
	"CS": true, "EE": true, "ME": true, "CE": true,
}

var validActivityTypes = map[string]bool{
	"fee": true, "library": true, "exam": true,
}

// activityDeptMap defines which staff department can record each activity type
// e.g. only "finance" staff can record "fee" activities
var activityDeptMap = map[string]string{
	"fee":     "finance",
	"library": "library",
	"exam":    "", // department staff OR registrar (checked separately)
}

// ─────────────────────────────────────────────
// Identity Helpers
// ─────────────────────────────────────────────

// getAttr reads an attribute from the client's X.509 enrollment certificate.
// Attributes are set when registering users with Fabric CA:
//
//	fabric-ca-client register --id.attrs "role=registrar:ecert,department=finance:ecert"
func getAttr(ctx contractapi.TransactionContextInterface, attr string) (string, error) {
	val, found, err := ctx.GetClientIdentity().GetAttributeValue(attr)
	if err != nil {
		return "", fmt.Errorf("error reading attribute %s: %v", attr, err)
	}
	if !found {
		return "", nil
	}
	return val, nil
}

// getMSPID returns the MSP ID of the calling client's organisation.
func getMSPID(ctx contractapi.TransactionContextInterface) string {
	id, err := cid.GetMSPID(ctx.GetStub())
	if err != nil {
		return "unknown"
	}
	return id
}

// ─────────────────────────────────────────────
// Chaincode Functions
// ─────────────────────────────────────────────

// RegisterStudent creates a new student record on the ledger.
//
// Access: role=registrar OR role=admin
//
// Invoke: peer chaincode invoke ... -c '{"Args":["RegisterStudent","S001","Alice","CS"]}'
func (s *SmartContract) RegisterStudent(
	ctx contractapi.TransactionContextInterface,
	id, name, department string,
) error {
	// ── Access Control ──────────────────────────────────────────────────────────
	role, err := getAttr(ctx, "role")
	if err != nil {
		return err
	}
	if role != "registrar" && role != "admin" {
		return fmt.Errorf("access denied: only registrar or admin can register students (your role: %q)", role)
	}

	// ── Validation ───────────────────────────────────────────────────────────────
	if id == "" || name == "" {
		return fmt.Errorf("id and name are required")
	}
	if !validDepartments[department] {
		return fmt.Errorf("invalid department %q; valid values: CS, EE, ME, CE", department)
	}

	// ── Duplicate Check ──────────────────────────────────────────────────────────
	existing, err := ctx.GetStub().GetState(id)
	if err != nil {
		return fmt.Errorf("failed to read world state: %v", err)
	}
	if existing != nil {
		return fmt.Errorf("student %s already exists", id)
	}

	// ── Persist ──────────────────────────────────────────────────────────────────
	student := Student{
		ID:         id,
		Name:       name,
		Department: department,
		Activities: []Activity{},
		CreatedAt:  time.Now().Format(time.RFC3339),
	}

	data, err := json.Marshal(student)
	if err != nil {
		return fmt.Errorf("failed to marshal student: %v", err)
	}

	// Composite key enables GetStudentsByDepartment range queries
	compKey, err := ctx.GetStub().CreateCompositeKey("dept~student", []string{department, id})
	if err != nil {
		return fmt.Errorf("failed to create composite key: %v", err)
	}
	if err := ctx.GetStub().PutState(compKey, []byte{0x00}); err != nil {
		return fmt.Errorf("failed to store composite key: %v", err)
	}

	return ctx.GetStub().PutState(id, data)
}

// AddActivity appends an activity to a student's record.
//
// Access rules (department-based):
//   - role=admin          → can add any activity for any student
//   - role=registrar      → can add exam activities
//   - role=staff, dept=finance  → can add fee activities
//   - role=staff, dept=library  → can add library activities
//   - role=staff, dept=<X>      → can add exam activities for students in dept <X>
//
// Invoke: peer chaincode invoke ... -c '{"Args":["AddActivity","S001","fee","Semester fee paid: 5000"]}'
func (s *SmartContract) AddActivity(
	ctx contractapi.TransactionContextInterface,
	studentID, activityType, details string,
) error {
	// ── Validate Activity Type Early ─────────────────────────────────────────────
	if !validActivityTypes[activityType] {
		return fmt.Errorf("invalid activity type %q; valid values: fee, library, exam", activityType)
	}

	// ── Load Student ─────────────────────────────────────────────────────────────
	studentJSON, err := ctx.GetStub().GetState(studentID)
	if err != nil {
		return fmt.Errorf("failed to read world state: %v", err)
	}
	if studentJSON == nil {
		return fmt.Errorf("student %s does not exist", studentID)
	}

	var student Student
	if err := json.Unmarshal(studentJSON, &student); err != nil {
		return fmt.Errorf("failed to unmarshal student: %v", err)
	}

	// ── Access Control ──────────────────────────────────────────────────────────
	role, err := getAttr(ctx, "role")
	if err != nil {
		return err
	}
	clientDept, err := getAttr(ctx, "department")
	if err != nil {
		return err
	}

	switch role {
	case "admin":
		// Full access — no further checks needed

	case "registrar":
		// Registrar may only record exam activities
		if activityType != "exam" {
			return fmt.Errorf("access denied: registrar can only add exam activities")
		}

	case "staff":
		if clientDept == "" {
			return fmt.Errorf("access denied: staff must have a 'department' attribute in their certificate")
		}
		switch activityType {
		case "fee":
			if clientDept != "finance" {
				return fmt.Errorf("access denied: only finance staff can record fee payments (your dept: %q)", clientDept)
			}
		case "library":
			if clientDept != "library" {
				return fmt.Errorf("access denied: only library staff can record library transactions (your dept: %q)", clientDept)
			}
		case "exam":
			// Dept staff can record exams only for their own department's students
			if clientDept != student.Department {
				return fmt.Errorf(
					"access denied: you are %q staff; student %s belongs to %q department",
					clientDept, studentID, student.Department,
				)
			}
		}

	default:
		return fmt.Errorf("access denied: unrecognised role %q", role)
	}

	// ── Append Activity ───────────────────────────────────────────────────────────
	activity := Activity{
		Type:       activityType,
		Details:    details,
		Timestamp:  time.Now().Format(time.RFC3339),
		RecordedBy: getMSPID(ctx),
		StaffDept:  clientDept,
	}

	student.Activities = append(student.Activities, activity)

	updated, err := json.Marshal(student)
	if err != nil {
		return fmt.Errorf("failed to marshal student: %v", err)
	}

	return ctx.GetStub().PutState(studentID, updated)
}

// GetStudent returns a student's current state.
//
// Access: any authenticated client
//
// Query: peer chaincode query ... -c '{"Args":["GetStudent","S001"]}'
func (s *SmartContract) GetStudent(
	ctx contractapi.TransactionContextInterface,
	id string,
) (*Student, error) {
	data, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read world state: %v", err)
	}
	if data == nil {
		return nil, fmt.Errorf("student %s does not exist", id)
	}

	var student Student
	if err := json.Unmarshal(data, &student); err != nil {
		return nil, fmt.Errorf("failed to unmarshal student: %v", err)
	}
	return &student, nil
}

// GetStudentsByDepartment returns all students in a given department.
//
// Access: any authenticated client
//
// Query: peer chaincode query ... -c '{"Args":["GetStudentsByDepartment","CS"]}'
func (s *SmartContract) GetStudentsByDepartment(
	ctx contractapi.TransactionContextInterface,
	department string,
) ([]*Student, error) {
	if !validDepartments[department] {
		return nil, fmt.Errorf("invalid department %q; valid values: CS, EE, ME, CE", department)
	}

	iter, err := ctx.GetStub().GetStateByPartialCompositeKey("dept~student", []string{department})
	if err != nil {
		return nil, fmt.Errorf("composite key query failed: %v", err)
	}
	defer iter.Close()

	var students []*Student
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("iterator error: %v", err)
		}
		_, parts, err := ctx.GetStub().SplitCompositeKey(kv.Key)
		if err != nil || len(parts) < 2 {
			continue
		}
		student, err := s.GetStudent(ctx, parts[1]) // parts[1] = student ID
		if err != nil {
			continue // skip deleted / corrupt records
		}
		students = append(students, student)
	}

	if students == nil {
		students = []*Student{} // return empty array, not null
	}
	return students, nil
}

// GetStudentHistory returns the full transaction history for a student from the ledger.
// Each entry includes the tx ID, timestamp, and the student state at that point in time.
//
// Access: role=admin OR role=registrar
//
// Query: peer chaincode query ... -c '{"Args":["GetStudentHistory","S001"]}'
func (s *SmartContract) GetStudentHistory(
	ctx contractapi.TransactionContextInterface,
	id string,
) ([]map[string]interface{}, error) {
	// ── Access Control ──────────────────────────────────────────────────────────
	role, err := getAttr(ctx, "role")
	if err != nil {
		return nil, err
	}
	if role != "admin" && role != "registrar" {
		return nil, fmt.Errorf("access denied: only admin or registrar can view transaction history")
	}

	// ── History Iterator ─────────────────────────────────────────────────────────
	iter, err := ctx.GetStub().GetHistoryForKey(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get history: %v", err)
	}
	defer iter.Close()

	var history []map[string]interface{}
	for iter.HasNext() {
		mod, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("history iterator error: %v", err)
		}

		record := map[string]interface{}{
			"txId":      mod.TxId,
			"timestamp": time.Unix(mod.Timestamp.Seconds, int64(mod.Timestamp.Nanos)).Format(time.RFC3339),
			"isDelete":  mod.IsDelete,
		}

		if len(mod.Value) > 0 && !mod.IsDelete {
			var student Student
			if err := json.Unmarshal(mod.Value, &student); err == nil {
				record["value"] = student
			}
		}

		history = append(history, record)
	}

	if history == nil {
		history = []map[string]interface{}{}
	}
	return history, nil
}

// ─────────────────────────────────────────────
// Entry Point
// ─────────────────────────────────────────────

func main() {
	cc, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		fmt.Printf("Error creating student-ledger chaincode: %v\n", err)
		return
	}
	if err := cc.Start(); err != nil {
		fmt.Printf("Error starting student-ledger chaincode: %v\n", err)
	}
}
