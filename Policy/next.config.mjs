/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return [
      {
        source: '/api/ola/:path*',
        destination: 'https://api.olamaps.io/:path*'
      }
    ];
  }
};

export default nextConfig;
