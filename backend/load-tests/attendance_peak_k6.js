import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';

const baseUrl = __ENV.BASE_URL || 'https://localhost:8888';
const mode = __ENV.MODE || 'face-check';
const username = __ENV.USERNAME;
const password = __ENV.PASSWORD;
const imageContentType = __ENV.IMAGE_CONTENT_TYPE || 'image/jpeg';
const devicePrefix = __ENV.DEVICE_PREFIX || 'loadtest-peak';

const employees = new SharedArray('employees', () => {
  const fixturePath = __ENV.EMPLOYEE_FIXTURE || './attendance_employees.sample.json';
  return JSON.parse(open(fixturePath)).employees;
});

export const options = {
  scenarios: {
    peak_attendance: {
      executor: 'ramping-arrival-rate',
      timeUnit: '1m',
      preAllocatedVUs: Number(__ENV.PREALLOCATED_VUS || 20),
      maxVUs: Number(__ENV.MAX_VUS || 80),
      stages: [
        { duration: '1m', target: 10 },
        { duration: '8m', target: 50 },
        { duration: '1m', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<3000'],
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['min', 'avg', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export function setup() {
  return {
    token: __ENV.ACCESS_TOKEN || login(),
  };
}

export default function (data) {
  const employee = employees[exec.scenario.iterationInTest % employees.length];
  if (mode === 'offline-sync') {
    syncOffline(employee, data.token);
  } else {
    faceCheck(employee, data.token);
  }
  sleep(Math.random() * 3);
}

function faceCheck(employee, token) {
  const response = http.post(
    `${baseUrl}/api/v1/attendance/face-check`,
    JSON.stringify({
      faceImageBase64: employee.faceImageBase64,
      imageContentType,
      deviceId: `${devicePrefix}-${employee.employeeCode || employee.employeeId}`,
    }),
    params('attendance_face_check', token),
  );

  check(response, {
    'face-check status is 2xx/4xx': (r) => r.status >= 200 && r.status < 500,
    'face-check not server error': (r) => r.status < 500,
  });
}

function syncOffline(employee, token) {
  const now = new Date();
  const localLogId = [
    devicePrefix,
    employee.employeeId,
    exec.scenario.iterationInTest,
    now.getTime(),
  ].join(':');

  const response = http.post(
    `${baseUrl}/api/v1/attendance/sync`,
    JSON.stringify({
      logs: [
        {
          localLogId,
          employeeId: employee.employeeId,
          type: employee.type || 'IN',
          checkTime: now.toISOString(),
          mobileCheckTime: now.toISOString(),
          confidenceScore: employee.expectedScore || 0.9,
          faceImageBase64: employee.faceImageBase64,
          imageContentType,
          deviceId: `${devicePrefix}-${employee.employeeCode || employee.employeeId}`,
          note: 'k6 peak attendance load test',
        },
      ],
    }),
    params('attendance_offline_sync', token),
  );

  check(response, {
    'offline-sync status is 2xx/4xx': (r) => r.status >= 200 && r.status < 500,
    'offline-sync not server error': (r) => r.status < 500,
  });
}

function params(name, token) {
  return {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'X-Request-Id': `${name}-${exec.scenario.iterationInTest}`,
    },
    tags: { name },
    timeout: __ENV.REQUEST_TIMEOUT || '30s',
  };
}

function login() {
  if (!username || !password) {
    throw new Error('Set ACCESS_TOKEN or USERNAME/PASSWORD for the load test.');
  }
  const response = http.post(
    `${baseUrl}/api/v1/auth/login`,
    JSON.stringify({ username, password }),
    {
      headers: { 'Content-Type': 'application/json' },
      timeout: '30s',
      tags: { name: 'auth_login' },
    },
  );
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`Login failed: status=${response.status}, body=${response.body}`);
  }
  const decoded = response.json();
  const data = decoded.data || decoded;
  if (!data.accessToken) {
    throw new Error('Login response does not contain accessToken.');
  }
  return data.accessToken;
}
