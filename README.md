# docker creation for FullOn Network

1. create a container for FullOn CDT environment
2. create containers for FullOn nodes:
   1. FullOn BP nodes with BP plugin turned on
   2. FullOn Common nodes with history API, state history and trace plugin turned on or off

1. RUN funod step
   a. change ~/flon.env 
   b. if no devnet change ~/flon.bp.env
   c. cd flon.chain/node-run
   d. 