# BRAVE Social Growth Marketplace

Full-stack Node.js/Express website with an original BRAVE storefront design, six platform categories, 37+ service cards, NGN pricing, checkout, order IDs and a Dockerfile.

## Run locally
```bash
npm install
npm start
```
Open http://localhost:3000

## Change the NGN conversion rate
```bash
NGN_PER_USD=1400 npm start
```
Default: `1332` NGN/USD. Update this value before production based on the rate/pricing you choose.

## Docker
```bash
docker build -t brave-social:1.0 .
docker run -d --restart unless-stopped --name brave-social -p 3000:3000 brave-social:1.0
```

## GitHub
```bash
git init
git add .
git commit -m "Build BRAVE social growth marketplace"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/brave-social-growth.git
git push -u origin main
```

## Azure VM
```bash
git clone https://github.com/YOUR-USERNAME/brave-social-growth.git
cd brave-social-growth
docker build -t brave-social:1.0 .
docker run -d --restart unless-stopped --name brave-social -p 3000:3000 brave-social:1.0
```

The current MVP stores orders in `data/orders.json`. For production, connect PostgreSQL/MySQL, authentication, a payment provider such as Paystack, an admin dashboard, HTTPS and secrets management.
