"use client";

import { useMemo, useState } from "react";
import { createItinerary } from "@/lib/actions/itinerary";

type DayState = { date: string; stops: string[] };

function buildDays(startDate: string, endDate: string): DayState[] {
  if (!startDate || !endDate) return [];
  const start = new Date(startDate);
  const end = new Date(endDate);
  if (end < start) return [];
  const days: DayState[] = [];
  const cursor = new Date(start);
  while (cursor <= end) {
    days.push({ date: cursor.toISOString().slice(0, 10), stops: [""] });
    cursor.setDate(cursor.getDate() + 1);
  }
  return days;
}

export default function TripForm({ error }: { error?: string }) {
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [days, setDays] = useState<DayState[]>([]);

  function handleDatesChange(nextStart: string, nextEnd: string) {
    setStartDate(nextStart);
    setEndDate(nextEnd);
    setDays(buildDays(nextStart, nextEnd));
  }

  function updateStop(dayIndex: number, stopIndex: number, value: string) {
    setDays((prev) =>
      prev.map((d, i) =>
        i === dayIndex ? { ...d, stops: d.stops.map((s, j) => (j === stopIndex ? value : s)) } : d
      )
    );
  }

  function addStop(dayIndex: number) {
    setDays((prev) => prev.map((d, i) => (i === dayIndex ? { ...d, stops: [...d.stops, ""] } : d)));
  }

  function removeStop(dayIndex: number, stopIndex: number) {
    setDays((prev) =>
      prev.map((d, i) => (i === dayIndex ? { ...d, stops: d.stops.filter((_, j) => j !== stopIndex) } : d))
    );
  }

  const daysPayload = useMemo(
    () =>
      JSON.stringify(
        days.map((d) => ({ dayDate: d.date, stops: d.stops.filter((s) => s.trim().length > 0) }))
      ),
    [days]
  );

  return (
    <form action={createItinerary} className="flex flex-col gap-4">
      {error && <p className="text-sm text-red-600">{error}</p>}

      <div className="grid grid-cols-2 gap-3">
        <input name="pickupLocation" placeholder="Pickup location" required className="rounded border px-3 py-2" />
        <input name="dropLocation" placeholder="Drop location" required className="rounded border px-3 py-2" />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <input
          name="startDate"
          type="date"
          required
          value={startDate}
          onChange={(e) => handleDatesChange(e.target.value, endDate)}
          className="rounded border px-3 py-2"
        />
        <input
          name="endDate"
          type="date"
          required
          value={endDate}
          onChange={(e) => handleDatesChange(startDate, e.target.value)}
          className="rounded border px-3 py-2"
        />
      </div>

      <input
        name="passengerCount"
        type="number"
        min={1}
        placeholder="Number of passengers"
        required
        className="rounded border px-3 py-2"
      />

      <input name="vehiclePreference" placeholder="Vehicle preference (optional)" className="rounded border px-3 py-2" />
      <input name="luggageRequirements" placeholder="Luggage requirements (optional)" className="rounded border px-3 py-2" />
      <textarea name="specialRequirements" placeholder="Special requirements (optional)" className="rounded border px-3 py-2" />
      <textarea name="additionalNotes" placeholder="Additional notes (optional)" className="rounded border px-3 py-2" />

      {days.length > 0 && (
        <div className="flex flex-col gap-4">
          <h2 className="font-semibold">Day-by-day stops</h2>
          {days.map((day, dayIndex) => (
            <div key={day.date} className="flex flex-col gap-2 rounded border p-3">
              <p className="text-sm text-neutral-500">
                Day {dayIndex + 1} — {day.date}
              </p>
              {day.stops.map((stop, stopIndex) => (
                <div key={stopIndex} className="flex gap-2">
                  <input
                    value={stop}
                    onChange={(e) => updateStop(dayIndex, stopIndex, e.target.value)}
                    placeholder="Stop name"
                    className="flex-1 rounded border px-3 py-2"
                  />
                  {day.stops.length > 1 && (
                    <button
                      type="button"
                      onClick={() => removeStop(dayIndex, stopIndex)}
                      className="rounded border px-3"
                    >
                      Remove
                    </button>
                  )}
                </div>
              ))}
              <button
                type="button"
                onClick={() => addStop(dayIndex)}
                className="w-fit rounded border px-3 py-1 text-sm"
              >
                Add stop
              </button>
            </div>
          ))}
        </div>
      )}

      <input type="hidden" name="days" value={daysPayload} />

      <button type="submit" className="rounded bg-black px-4 py-2 text-white">
        Post itinerary
      </button>
    </form>
  );
}
