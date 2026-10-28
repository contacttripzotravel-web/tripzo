import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { signOut } from "@/lib/actions/auth";

export default async function DashboardPage() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("users")
    .select("full_name, role")
    .eq("id", user.id)
    .single();

  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col gap-4 px-4 py-12">
      <h1 className="text-2xl font-bold">
        Welcome, {profile?.full_name ?? user.email}
      </h1>

      <p className="text-neutral-600">
        Role: {profile?.role}
      </p>

      {profile?.role === "guest" && (
        <div className="flex gap-3">
          <Link
            href="/trips/new"
            className="rounded bg-black px-4 py-2 text-white"
          >
            Post a trip
          </Link>

          <Link
            href="/trips"
            className="rounded border px-4 py-2"
          >
            My trips
          </Link>
        </div>
      )}

      <form action={signOut}>
        <button
          type="submit"
          className="w-fit rounded border px-4 py-2"
        >
          Log out
        </button>
      </form>
    </main>
  );
}
