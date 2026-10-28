
import { signUp } from "@/lib/actions/auth";

export default async function SignupPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;

  return (
    <main className="mx-auto flex min-h-screen max-w-sm flex-col justify-center gap-4 px-4">
      <h1 className="text-2xl font-bold">
        Create your Tripzo account
      </h1>

      {params.error && (
        <p className="text-sm text-red-600">
          {params.error}
        </p>
      )}

      <form action={signUp} className="flex flex-col gap-3">
        <input
          name="fullName"
          type="text"
          placeholder="Full name"
          required
          className="rounded border px-3 py-2"
        />

        <input
          name="email"
          type="email"
          placeholder="Email"
          required
          className="rounded border px-3 py-2"
        />

        <input
          name="password"
          type="password"
          placeholder="Password"
          minLength={8}
          required
          className="rounded border px-3 py-2"
        />

        <button
          type="submit"
          className="rounded bg-black px-3 py-2 text-white"
        >
          Sign up
        </button>
      </form>

      <a href="/login" className="text-sm underline">
        Already have an account? Log in
      </a>
    </main>
  );
}
