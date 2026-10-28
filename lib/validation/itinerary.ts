
import { z } from "zod";

export const itinerarySchema = z
  .object({
    pickupLocation: z.string().min(2),
    dropLocation: z.string().min(2),
    startDate: z.string().min(1),
    endDate: z.string().min(1),
    passengerCount: z.coerce.number().int().positive(),
    vehiclePreference: z.string().optional(),
    luggageRequirements: z.string().optional(),
    specialRequirements: z.string().optional(),
    additionalNotes: z.string().optional(),
    days: z
      .array(
        z.object({
          dayDate: z.string().min(1),
          stops: z.array(z.string().min(1)).min(1),
        })
      )
      .min(1),
  })
  .refine(
    (data) => new Date(data.endDate) >= new Date(data.startDate),
    {
      message: "End date must be on or after start date",
      path: ["endDate"],
    }
  );

export type ItineraryInput = z.infer<typeof itinerarySchema>;
