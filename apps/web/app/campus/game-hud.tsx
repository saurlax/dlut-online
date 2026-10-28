import GameSettings from '../../components/game-settings';

export default function GameHud({portal}: {portal:HTMLElement|null}) {
  return <GameSettings portal={portal} inGame />;
}
