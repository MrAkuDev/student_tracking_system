const { Route, Student } = require('../models');

const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

async function uniqueCode(Model, prefix, minDigits) {
  for (let attempt = 0; attempt < 60; attempt++) {
    const digits = attempt < 40 ? minDigits : minDigits + 1;
    const n = rand(10 ** (digits - 1), 10 ** digits - 1);
    const code = `${prefix}-${n}`;
    if (!(await Model.exists({ shortCode: code }))) return code;
  }
  throw new Error('No se pudo generar un código único');
}

const newRouteCode = () => uniqueCode(Route, 'RUT', 3);
const newStudentCode = () => uniqueCode(Student, 'ALU', 4);

module.exports = { newRouteCode, newStudentCode };
