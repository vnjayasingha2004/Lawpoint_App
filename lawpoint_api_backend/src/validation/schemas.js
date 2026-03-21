const { z } = require('zod');

const loginSchema = z
  .object({
    identifier: z.string().trim().min(3).max(120).optional(),
    email: z.string().trim().email().max(120).optional(),
    phone: z.string().trim().min(7).max(20).optional(),
    password: z.string().min(8).max(100),
  })
  .refine((v) => Boolean(v.identifier || v.email || v.phone), {
    message: 'identifier, email, or phone is required.',
    path: ['identifier'],
  });

const registerClientSchema = z.object({
  email: z.string().trim().email().max(120),
  password: z.string().min(8).max(100),
  firstName: z.string().trim().min(1).max(80),
  lastName: z.string().trim().min(1).max(80),
  phone: z.string().trim().min(7).max(20).optional().or(z.literal('')),
});

const dateTimeLikeSchema = z
  .string()
  .trim()
  .min(1, 'Date/time is required.')
  .refine(
    (value) =>
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})?$/.test(
        value
      ),
    {
      message: 'Must be a valid ISO date-time.',
    }
  )
  .refine((value) => !Number.isNaN(new Date(value).getTime()), {
    message: 'Must be a valid date-time.',
  });

const createAppointmentSchema = z
  .object({
    lawyerId: z.string().trim().min(1, 'lawyerId is required.'),
    startAt: dateTimeLikeSchema,
    endAt: dateTimeLikeSchema,
  })
  .refine(
    (value) =>
      new Date(value.endAt).getTime() > new Date(value.startAt).getTime(),
    {
      message: 'endAt must be after startAt.',
      path: ['endAt'],
    }
  );

const updateCaseStatusSchema = z.object({
  status: z.enum(['OPEN', 'IN_PROGRESS', 'WAITING_CLIENT', 'CLOSED']),
});

const rejectVerificationSchema = z.object({
  reason: z.string().trim().min(5).max(500),
});

module.exports = {
  loginSchema,
  registerClientSchema,
  createAppointmentSchema,
  updateCaseStatusSchema,
  rejectVerificationSchema,
};