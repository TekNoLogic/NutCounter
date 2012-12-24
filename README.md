NutCounter is a basic AH stat addon inspired by Auctioneer's BeanCounter.  It strives for low resource use while keeping a few basic stats about your auctions:

* Sellthrough (percent of total auctions posted which were successful)
* Last sell price
* Min and max sell price

Note that due to the way the mailbox returns invoices, items are tracked by name not itemID.

NutCounter also implements the global API @GetAuctionBuyout(item)@.  This will prefer values provided by other addons that implement @GetAuctionBuyout@ first, if none are given it will return your last price from the item.

h2. Links

<b>Visit "my site":http://tekkub.net/ for more great addons<br>
Please report all bugs and feature requests to my "Github tracker":http://github.com/tekkub/NutCounter/issues<br>
Please direct all feedback and questions to my "Google Groups":http://groups-beta.google.com/group/tekkub-wow mailinglist.</b>
