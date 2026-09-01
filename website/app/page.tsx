import { Compatibility } from "@/components/compatibility";
import { Download } from "@/components/download";
import { Features } from "@/components/features";
import { Footer } from "@/components/footer";
import { Hero } from "@/components/hero";
import { How } from "@/components/how";
import { Nav } from "@/components/nav";
import { Problem } from "@/components/problem";
import { Workspace } from "@/components/workspace";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Problem />
        <Workspace />
        <Features />
        <How />
        <Compatibility />
        <Download />
      </main>
      <Footer />
    </>
  );
}
