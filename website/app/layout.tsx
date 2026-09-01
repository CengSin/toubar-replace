import type { Metadata } from "next";
import { Geist, Noto_Sans_SC } from "next/font/google";
import "./globals.css";
import { SITE } from "@/lib/site";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
  display: "swap",
});

const noto = Noto_Sans_SC({
  variable: "--font-noto",
  subsets: ["latin"],
  weight: ["400", "500", "700"],
  display: "swap",
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: `${SITE.name} · ${SITE.tagline}`,
  description: SITE.description,
  applicationName: SITE.name,
  icons: {
    icon: "/icon.png",
    apple: "/apple-icon.png",
  },
  openGraph: {
    type: "website",
    locale: "zh_CN",
    title: `${SITE.name} · ${SITE.tagline}`,
    description: SITE.description,
    siteName: SITE.name,
    images: [
      {
        url: "/og.jpg",
        width: 1200,
        height: 630,
        type: "image/jpeg",
        alt: `${SITE.name}：手指一点，打开 Agent`,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: `${SITE.name} · ${SITE.tagline}`,
    description: SITE.description,
    images: ["/og.jpg"],
  },
};

const themeScript = `(function(){try{var t=localStorage.getItem("toubar-theme");if(t!=="light"&&t!=="dark"){t=window.matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light";}document.documentElement.dataset.theme=t;}catch(e){document.documentElement.dataset.theme="dark";}})();`;

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: SITE.name,
  applicationCategory: "DeveloperApplication",
  operatingSystem: "macOS 14+",
  description: SITE.description,
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "CNY",
  },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="zh-CN"
      className={`${geistSans.variable} ${noto.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body className="min-h-full bg-bg font-sans text-ink">
        <noscript>
          <style
            dangerouslySetInnerHTML={{
              __html:
                "[data-motion]{opacity:1!important;transform:none!important}",
            }}
          />
        </noscript>
        <a
          href="#workspace"
          className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-cta focus:px-4 focus:py-2 focus:text-cta-ink"
        >
          跳到内容
        </a>
        {children}
      </body>
    </html>
  );
}
